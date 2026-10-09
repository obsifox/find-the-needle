class_name GiftCard
extends Control


const REF_H:= 1080.0
const CARD_W:= 540.0
const CARD_H:= 740.0
const ICON:= 220.0
const ROLL_ICON:= 150.0


const Y_NAME:= -0.37
const Y_PRICE:= -0.305
const Y_STAMP:= -0.165
const Y_ICON:= 0.06


const Y_MOUTH:= 0.235
const Y_HINT:= 0.445


const CARD_LIFT:= 75.0


const T_LINE:= 0.1
const T_OPEN:= 0.24
const T_CHEST:= 0.36


const HOPS:= [[0.84, 0.2, 0.05], [1.06, 0.16, 0.07], [1.23, 0.13, 0.09], [1.36, 0.11, 0.11]]
const T_CRACK:= 1.5


const T_BURST:= 1.92
const T_ROLL:= 1.98
const T_REVEAL:= 3.14
const T_TITLE:= 3.5
const T_NAME:= 3.7
const T_PRICE:= 3.9
const T_STRIKE:= 4.25
const T_STAMP:= 4.55
const T_HINT:= 4.95
const T_HOLD:= 9.0
const T_FADE:= 0.5

const SHINE_EVERY:= 2.4


const ROLL_STEPS:= 16
const ROLL_FIRST:= 0.05
const ROLL_LAST:= 0.12


const ROLL_POOL:= ["arm", "compressor", "drone", "wrapper", "scanner",
	"pelletizer", "cabinet", "rake", "launcher", "silo", "generator",
	"borehole", "pulper", "paper_machine", "haylift", "briquette_press",
	"needle_radar"]

const T_TUMBLE:= 0.5


const MUSIC_UNDER:= 0.03

const COL_DIM:= Color(0.02, 0.02, 0.03)
const DIM_ALPHA:= 0.58
const COL_CARD:= Color(0.035, 0.105, 0.13, 0.94)


const COL_GOLD_DEEP:= Color(0.5, 0.32, 0.09)
const COL_GOLD_MID:= Color(0.88, 0.66, 0.26)
const COL_GOLD_HI:= Color(1.0, 0.95, 0.72)

const GLINT_LAP:= 3.2
const COL_TITLE:= Color(1.0, 0.86, 0.34)
const COL_NAME:= Color(1.0, 0.97, 0.9)
const COL_PRICE:= Color(0.78, 0.8, 0.84)
const COL_STRIKE:= Color(0.95, 0.24, 0.2)
const COL_HINT:= Color(0.84, 0.86, 0.9)
const COL_BEAM:= Color(0.4, 1.0, 0.78)
const COL_GOLD:= Color(1.0, 0.84, 0.36)


const COL_BANNER_TOP:= Color(0.9, 0.2, 0.22)
const COL_BANNER_LOW:= Color(0.6, 0.05, 0.1)
const COL_BANNER_TAIL:= Color(0.46, 0.04, 0.08)
const COL_BANNER_FOLD:= Color(0.26, 0.01, 0.04)
const COL_TRIM:= Color(1.0, 0.82, 0.38)


const OPEN_MARK:= "user://gift_card_open"


const TAKE_W:= 280.0
const TAKE_H:= 70.0
const TAKE_BELOW:= 68.0
const COL_TAKE_INK:= Color(0.22, 0.11, 0.02)

const BANNER_W:= 250.0
const BANNER_H:= 64.0
const BANNER_TAIL:= 44.0


const CHEST_PATH:= "res://assets/downloaded/models/medieval_chest/compiled/medieval_chest.scn"


const CHEST_SCALE:= 0.85

const CHEST_NUDGE:= Vector3(0.0, 0.0, -0.015)


const CHEST_CLIP:= "Armature_001|ArmatureAction_001"
const BONE_LID:= "TopBone"
const BONE_HASP:= "FrontBone"


const LOCK_BEATS:= [[0.7, 0.1], [1.1, 0.75], [1.5, 1.5], [1.62, 1.6]]


const LOCK_FALL:= 0.35
const LOCK_GONE:= 0.3


const LID_CLIP_SHUT:= 1.6
const LID_CLIP_OPEN:= 2.6
const HASP_CLIP_FLOP:= 3.0


const MOUTH:= Vector3(0.0, 0.39, 0.0)


const PX_PER_M:= 250.0
const CAM_FOV:= 20.0


const CAM_PITCH:= 16.0


const LID_CRACK:= 12.0
const LID_OPEN:= 116.0


const BEAMS:= [[0.0, 0.46, 2.6], [-9.0, 0.16, 2.1], [9.0, 0.16, 2.1], [-18.0, 0.14, 1.8],
	[18.0, 0.14, 1.8], [-28.0, 0.12, 1.5], [28.0, 0.12, 1.5], [-39.0, 0.1, 1.2], [39.0, 0.1, 1.2]]


const BEAM_FOOT:= 0.24


const PRIZES:= {
	"rake": PistonRake.MODEL,
	"cabinet": NeedleCabinet.MODEL,
	"pole": PowerPole.MODEL,
}


const PRIZE_AT:= Vector3(0.0, 1.12, 0.08)


const PRIZE_TOP:= 1.42


const PRIZE_HIDDEN:= Vector3(0.0, 0.12, 0.16)


const PRIZE_FIT:= Vector2(1.2, 0.9)

const PRIZE_TURN:= 0.7


const BEAM_SHADER:= "\nshader_type spatial;\nrender_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;\n\n// One shaft of light out of the chest, on a quad standing on its foot inside\n// it. UV.y is 1 at the foot and 0 at the tip. `reach` is how far up the shaft\n// has grown, 0 to 1.\nuniform vec4 tint : source_color = vec4(0.40, 1.0, 0.78, 1.0);\nuniform float reach = 0.0;\nuniform float gain = 0.0;\nuniform float seed = 0.0;\nuniform float core = 0.0;\n\nvoid fragment() {\n\tfloat along = 1.0 - UV.y;\n\tfloat across = abs(UV.x * 2.0 - 1.0);\n\tfloat edge = 1.0 - smoothstep(core * 0.45, 1.0, across);\n\tfloat tip = 1.0 - smoothstep(reach - 0.35, reach, along);\n\tfloat foot = 1.0 + 1.6 * exp(-along * 7.0);\n\tfloat shimmer = 0.82 + 0.18 * sin(TIME * 21.0 + seed * 13.0 - along * 11.0);\n\tfloat hot = clamp((1.0 - across) * foot - 0.9, 0.0, 1.0);\n\tALBEDO = mix(tint.rgb, vec3(1.0), hot * 0.7);\n\tALPHA = clamp(edge * tip * foot * shimmer * gain, 0.0, 1.0);\n}\n"


const SUNBURST:= preload("res://assets/ui/effects/effect_yellow.png")

const SHINE_SHADER:= "\nshader_type canvas_item;\n\n// A band of light crossing the picture on the slant, the way light runs over\n// a new thing turned in the hand. `sweep` walks it from off the left edge to\n// off the right one.\n//\n// Also a thin rim in the beams' colour round the picture, and its shadows\n// lifted a little: these are photographs of dark machines, and against the\n// rays a dark machine is a hole in the light.\n//\n// The pictures are tiles of one sheet, so `region` is this tile's part of\n// the sheet in UV. The sweep crosses the tile rather than the whole sheet,\n// and the rim never samples the tile next door.\n//\n// The rim follows the SOLID machine, not the picture's alpha: every picture\n// stands in a soft grey haze under a third opaque, and a rim round the haze\n// is a rim round nothing.\nuniform float sweep = -1.0;\nuniform float width = 0.16;\nuniform float gain = 0.85;\nuniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);\nuniform vec4 rim : source_color = vec4(0.55, 1.0, 0.85, 1.0);\nuniform float rim_px = 6.0;\nuniform float lift = 0.55;\n// 1 while the chest spins: every picture going by is a black cut-out of the\n// solid machine, haze dropped, and only the gift is shown in its colours.\nuniform float silhouette = 0.0;\n\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tc.rgb = pow(c.rgb, vec3(1.0 / (1.0 + lift)));\n\tc.rgb = mix(c.rgb, vec3(0.0), silhouette);\n\tc.a = mix(c.a, smoothstep(0.6, 0.9, c.a), silhouette);\n\tvec2 lo = region.xy;\n\tvec2 hi = region.xy + region.zw;\n\tfloat around = 0.0;\n\tfor (int i = 0; i < 12; i++) {\n\t\tfloat a = float(i) * 0.5235988;\n\t\tvec2 at = clamp(UV + vec2(cos(a), sin(a)) * rim_px * TEXTURE_PIXEL_SIZE, lo, hi);\n\t\taround = max(around, smoothstep(0.6, 0.9, texture(TEXTURE, at).a));\n\t}\n\tfloat edge = around * (1.0 - smoothstep(0.6, 0.9, c.a));\n\tvec2 local = (UV - lo) / region.zw;\n\tfloat d = abs((local.x + (1.0 - local.y) * 0.55) - sweep * 1.55);\n\tfloat s = smoothstep(width, 0.0, d);\n\tc.rgb += vec3(1.0, 0.95, 0.80) * s * gain * c.a;\n\tCOLOR = vec4(mix(c.rgb, rim.rgb, edge), max(c.a, edge)) * COLOR;\n}\n"


signal finished

var _id:= ""
var _t:= 0.0
var _running:= false
var _fading:= 0.0
var _revealed:= false

var _then:= Callable()


var hud_layer: CanvasLayer
var _hid_hud:= false


var _holds:= false
var _take: Control
var _take_label: Label
var _take_keys: Label
var _take_hover:= false

var _take_glow:= 0.0

var _take_press:= 0.0
var _rng:= RandomNumberGenerator.new()


var _roll_ids: Array [String] = []
var _roll_times: Array [float] = []
var _roll_next:= 0
var _roll_since:= 0.0
var _roll_tilt:= 0.0

var _icon_at:= Vector2.ZERO


var _splash: Array [Vector3] = []


var _sun_a: TextureRect
var _sun_b: TextureRect
var _icon: TextureRect
var _shine_mat: ShaderMaterial
var _title: Label
var _name: Label
var _price: Label
var _banner: Control
var _stamp_label: Label

var _banner_w:= BANNER_W
var _hint: Label
var _coins: CPUParticles2D
var _glints: CPUParticles2D
var _sparks: CPUParticles2D
var _streaks: CPUParticles2D
var _shards: CPUParticles2D
var _stamp_sparks: CPUParticles2D

var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D
var _inner: OmniLight3D
var _chest_view: TextureRect
var _chest: Node3D


var _skel: Skeleton3D
var _clip: Animation
var _lid_bone:= -1
var _lid_shut:= Quaternion.IDENTITY
var _lid_axis:= Vector3.RIGHT
var _chest_failed:= false
var _beam_mats: Array [ShaderMaterial] = []


var _prize: Node3D
var _prize_path:= ""
var _prize_failed:= false

var _prize_half_h:= 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	_rng.randomize()
	_build()


func _exit_tree() -> void:
	if _running:
		Audio.ui_loop_stop("chest_aura", 0.3)
		Audio.music_unduck(0.5)

		_clear_mark()
		_hide_hud(false)


static func went_down_in_one(id: String) -> bool:
	if not FileAccess.file_exists(OPEN_MARK):
		return false
	var was:= FileAccess.get_file_as_string(OPEN_MARK).strip_edges()
	_clear_mark()
	return was == id


static func _clear_mark() -> void:
	if FileAccess.file_exists(OPEN_MARK):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OPEN_MARK))


func _build() -> void:
	_back = _layer("Dim")
	_back.draw.connect(_draw_back)
	_front = _layer("Card")
	_front.draw.connect(_draw_front)


	_sun_a = _sun_layer("SunburstBack")
	_sun_b = _sun_layer("SunburstFront")

	_build_stage()

	_coins = _drifters("Coins", _tex_coin(), 16, 2.4)
	_glints = _drifters("Glints", _tex_glint(), 22, 1.3)

	_icon = TextureRect.new()
	_icon.name = "Building"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var shine:= Shader.new()
	shine.code = SHINE_SHADER
	_shine_mat = ShaderMaterial.new()
	_shine_mat.shader = shine
	_icon.material = _shine_mat
	add_child(_icon)

	_sparks = _particles("Sparks", 70, 0.9)
	_streaks = _streak_particles("Streaks", 26, 0.55)
	_shards = _streak_particles("Shards", 34, 0.45)

	_title = _label(46, COL_TITLE, true)
	_name = _label(34, COL_NAME, true)
	_price = _label(30, COL_PRICE, false)
	_hint = _label(24, COL_HINT, false)

	_over = _layer("Over")
	_over.draw.connect(_draw_over)


	_banner = _layer("Banner")
	_banner.draw.connect(_draw_banner)
	_stamp_label = Label.new()
	UiFont.style(_stamp_label, 50, Color(1.0, 0.98, 0.94), 8, true)
	_stamp_label.add_theme_color_override("font_outline_color", COL_BANNER_FOLD)
	_stamp_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
	_stamp_label.add_theme_constant_override("shadow_offset_x", 0)
	_stamp_label.add_theme_constant_override("shadow_offset_y", 4)
	_stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stamp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp_label.modulate.a = 0.0
	add_child(_stamp_label)

	_stamp_sparks = _particles("StampSparks", 40, 0.8)


	_take = _layer("Take")
	_take.draw.connect(_draw_take)
	_take_label = Label.new()
	UiFont.style(_take_label, 34, COL_TAKE_INK, 3, true)
	_take_label.add_theme_color_override("font_outline_color", Color(COL_GOLD_HI, 0.55))
	_take_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_take_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_take_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_take_label.modulate.a = 0.0
	_take.add_child(_take_label)
	_take_keys = _label(20, COL_HINT, false)


func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.name = "ChestStage"
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


	_vp.size = Vector2i(2, 2)
	add_child(_vp)

	var env:= Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.35, 0.37)
	env.ambient_light_energy = 0.55
	var we:= WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_cam.near = 1.0
	_cam.far = 40.0
	_vp.add_child(_cam)
	_place_camera()


	_sun(Vector3(-38.0, -32.0, 0.0), Color(1.0, 0.93, 0.82), 1.7)
	_sun(Vector3(-12.0, 58.0, 0.0), Color(0.72, 0.85, 1.0), 0.35)
	_sun(Vector3(-28.0, 172.0, 0.0), Color(0.7, 1.0, 0.9), 0.55)


	var lamp:= OmniLight3D.new()
	lamp.position = PRIZE_AT + Vector3(0.5, 0.5, 1.4)
	lamp.omni_range = 3.5
	lamp.light_color = Color(1.0, 0.97, 0.92)
	lamp.light_energy = 1.3
	_vp.add_child(lamp)


	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_vp.add_child(_pivot)

	_inner = OmniLight3D.new()
	_inner.position = Vector3(0.0, 0.22, 0.02)
	_inner.omni_range = 1.1
	_inner.light_color = COL_BEAM
	_inner.light_energy = 0.0
	_pivot.add_child(_inner)
	_build_beams()

	_chest_view = TextureRect.new()
	_chest_view.name = "Chest"
	_chest_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chest_view.stretch_mode = TextureRect.STRETCH_SCALE
	_chest_view.texture = _vp.get_texture()


	var pm:= CanvasItemMaterial.new()
	pm.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_chest_view.material = pm
	add_child(_chest_view)


func _sun(rot_deg: Vector3, colour: Color, energy: float) -> void:
	var l:= DirectionalLight3D.new()
	l.rotation_degrees = rot_deg
	l.light_color = colour
	l.light_energy = energy
	_vp.add_child(l)


func _place_camera() -> void:
	var tall:= CARD_H / PX_PER_M
	var d:= tall * 0.5 / tan(deg_to_rad(CAM_FOV * 0.5))
	var p:= deg_to_rad(CAM_PITCH)
	var up:= Vector3(0.0, cos(p), - sin(p))
	var fwd:= Vector3(0.0, - sin(p), - cos(p))
	var aim:= MOUTH + up * (Y_MOUTH * tall)
	_cam.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), aim - fwd * d)


func _build_beams() -> void:
	var sh:= Shader.new()
	sh.code = BEAM_SHADER
	for i in BEAMS.size():
		var b: Array = BEAMS [i]
		var hinge:= Node3D.new()
		hinge.position = Vector3(0.0, BEAM_FOOT, 0.0)
		hinge.rotation.z = deg_to_rad(float(b [0]))
		_pivot.add_child(hinge)
		var q:= QuadMesh.new()
		q.size = Vector2(float(b [1]), float(b [2]))
		var mi:= MeshInstance3D.new()
		mi.mesh = q
		mi.position = Vector3(0.0, float(b [2]) * 0.5, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m:= ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("tint", COL_BEAM)
		m.set_shader_parameter("seed", float(i) * 1.37)
		m.set_shader_parameter("core", 1.0 if i == 0 else 0.0)
		mi.material_override = m
		hinge.add_child(mi)
		_beam_mats.append(m)


func _ensure_chest() -> void:
	if _chest != null or _chest_failed:
		return
	var st:= ResourceLoader.load_threaded_get_status(CHEST_PATH)
	if st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(CHEST_PATH, "PackedScene")
		return
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var packed:= ResourceLoader.load_threaded_get(CHEST_PATH) as PackedScene
	if packed == null:

		_chest_failed = true
		push_warning("GiftCard: could not load %s" % CHEST_PATH)
		return
	_chest = packed.instantiate() as Node3D
	_chest.transform = Transform3D(Basis.from_scale(Vector3.ONE * CHEST_SCALE), CHEST_NUDGE)
	_pivot.add_child(_chest)
	_skel = _chest.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap:= _chest.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		if ap.has_animation(CHEST_CLIP):
			_clip = ap.get_animation(CHEST_CLIP)
		ap.get_parent().remove_child(ap)
		ap.free()
	if _skel == null or _clip == null:

		push_warning("GiftCard: %s has no %s to open with" % [CHEST_PATH, CHEST_CLIP])
		_clip = null
		return
	_lid_bone = _skel.find_bone(BONE_LID)
	var lid_track:= _bone_track(BONE_LID, Animation.TYPE_ROTATION_3D)
	if lid_track >= 0:
		_lid_shut = _clip.rotation_track_interpolate(lid_track, 0.0)
		var swing:= _lid_shut.inverse() * _clip.rotation_track_interpolate(lid_track, LID_CLIP_OPEN)
		_lid_axis = swing.get_axis()
	_pose_bones(0.0, 0.0, 0.0)


func _bone_track(bone: String, kind: int) -> int:
	for i in _clip.get_track_count():
		if _clip.track_get_type(i) == kind and _clip.track_get_path(i).get_concatenated_subnames() == bone:
			return i
	return -1


func _pose_bones(lock_t: float, hasp_t: float, lid_deg: float, gone:= 0.0) -> void:
	if _clip == null or _skel == null:
		return


	var fall:= (_skel.global_basis.inverse() * _pivot.global_basis) * (Vector3.DOWN * LOCK_FALL * gone * gone)
	for i in _clip.get_track_count():
		var bone_name:= _clip.track_get_path(i).get_concatenated_subnames()
		if bone_name == "" or bone_name == BONE_LID:
			continue
		var bone:= _skel.find_bone(bone_name)
		if bone < 0:
			continue
		var is_lock:= bone_name != BONE_HASP
		var at:= lock_t if is_lock else hasp_t
		match _clip.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				_skel.set_bone_pose_rotation(bone, _clip.rotation_track_interpolate(i, at))
			Animation.TYPE_POSITION_3D:
				var p:= _clip.position_track_interpolate(i, at)
				_skel.set_bone_pose_position(bone, p + fall if is_lock else p)
		if is_lock:
			_skel.set_bone_pose_scale(bone, Vector3.ONE * maxf(1.0 - gone, 0.001))
	if _lid_bone >= 0:
		_skel.set_bone_pose_rotation(_lid_bone,
			_lid_shut * Quaternion(_lid_axis, deg_to_rad(lid_deg)))


func _drop_chest() -> void:
	if _chest != null:
		_chest.queue_free()
	_chest = null
	_skel = null
	_clip = null
	_lid_bone = -1
	if _prize != null:
		_prize.queue_free()
	_prize = null


func _ensure_prize() -> void:
	if _prize != null or _prize_failed or _prize_path == "":
		return
	var st:= ResourceLoader.load_threaded_get_status(_prize_path)
	if st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(_prize_path, "PackedScene")
		return
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var packed:= ResourceLoader.load_threaded_get(_prize_path) as PackedScene
	if packed == null:
		_prize_failed = true
		push_warning("GiftCard: could not load %s, showing the picture instead" % _prize_path)
		return
	var model:= packed.instantiate() as Node3D
	_dress_prize(model)

	var box:= _bounds(model, Transform3D.IDENTITY)
	var across:= maxf(box.size.x, box.size.z)
	var k:= 1.0
	if across > 0.001 and box.size.y > 0.001:
		k = minf(PRIZE_FIT.x / across, PRIZE_FIT.y / box.size.y)
	model.scale = Vector3.ONE * k
	model.position = - box.get_center() * k
	_prize_half_h = box.size.y * k * 0.5
	_prize = Node3D.new()
	_prize.name = "Prize"
	_prize.add_child(model)
	_vp.add_child(_prize)


func _dress_prize(model: Node3D) -> void:
	var make: Callable
	var helper: Node = null
	match _id:
		"rake":
			var spec:= PistonRake.spec_table()
			var shader: Shader = load(HayCompressor.SHADER)
			make = func(key: String) -> Material: return HayCompressor.make_material(key, spec, shader)
		"pole":

			var spec:= PowerPole.spec_table_at(PowerPole.SPEC)
			var shader: Shader = load(HayCompressor.SHADER)
			make = func(key: String) -> Material: return HayCompressor.make_material(key, spec, shader)
		"cabinet":


			var ending:= model.find_child(NeedleCabinet.N_ENDPANEL, true, false) as Node3D
			if ending != null:
				ending.visible = false
			var cab:= NeedleCabinet.new()
			helper = cab
			var spec: Dictionary = cab._load_spec()
			var shader: Shader = load(NeedleCabinet.SHADER)
			make = func(key: String) -> Material: return cab._make_surface(key, spec, shader)
		_:
			return
	var built:= { }
	var stack: Array [Node] = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi:= n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue


		mi.lod_bias = 8.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var any:= false
		for i in mi.mesh.get_surface_count():
			var src:= mi.get_active_material(i)
			if src == null:
				continue
			any = true
			if src.get_meta("immutable_palette", false):
				continue
			var key:= src.resource_name
			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = make.call(key)
			if built [key] != null:
				mi.set_surface_override_material(i, built [key])
		if not any:
			mi.visible = false
	if helper != null:
		helper.free()


func _bounds(n: Node, xf: Transform3D) -> AABB:
	var box:= AABB()
	var first:= true
	var here:= xf * (n as Node3D).transform if n is Node3D and n != _prize else xf
	var mi:= n as MeshInstance3D
	if mi != null and mi.mesh != null and mi.visible:
		box = here * mi.get_aabb()
		first = false
	for c in n.get_children():
		var sub:= _bounds(c, here)
		if sub.size == Vector3.ZERO:
			continue
		box = sub if first else box.merge(sub)
		first = false
	return box


func _sun_layer(node_name: String) -> TextureRect:
	var r:= TextureRect.new()
	r.name = node_name
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture = SUNBURST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var add:= CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	r.material = add
	r.modulate.a = 0.0
	add_child(r)
	return r


func _label(size_px: int, colour: Color, heavy: bool) -> Label:
	var l:= Label.new()
	UiFont.style(l, size_px, colour, 6, heavy)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	add_child(l)
	return l


func _particles(node_name: String, amount: int, life: float) -> CPUParticles2D:
	var p:= _burst_base(node_name, amount, life)
	var grad:= Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex:= GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	p.texture = tex
	var shrink:= Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	return p


func _streak_particles(node_name: String, amount: int, life: float) -> CPUParticles2D:
	var p:= _burst_base(node_name, amount, life)
	p.texture = _tex_streak()
	p.particle_flag_align_y = true
	return p


func _burst_base(node_name: String, amount: int, life: float) -> CPUParticles2D:
	var p:= CPUParticles2D.new()
	p.name = node_name
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	var ramp:= Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 1.0, 0.92, 1.0), Color(1.0, 0.82, 0.3, 0.95),
		Color(1.0, 0.55, 0.1, 0.0)])
	p.color_ramp = ramp
	var add:= CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add
	add_child(p)
	return p


func _drifters(node_name: String, tex: Texture2D, amount: int, life: float) -> CPUParticles2D:
	var p:= CPUParticles2D.new()
	p.name = node_name
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.texture = tex
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.angle_min = -30.0
	p.angle_max = 30.0
	p.angular_velocity_min = -160.0
	p.angular_velocity_max = 160.0
	var fade:= Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1),
		Color(1, 1, 1, 0)])
	p.color_ramp = fade
	add_child(p)
	return p


static func _tex_coin() -> ImageTexture:
	var n:= 32
	var img:= Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c:= Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var p:= Vector2(x + 0.5, y + 0.5) - c
			var r:= p.length()
			var a:= clampf(14.5 - r, 0.0, 1.0)
			var col:= Color(1.0, 0.8, 0.24)
			if r > 11.5:
				col = Color(0.8, 0.52, 0.1)
			elif r > 8.5 and r < 9.7:
				col = Color(0.84, 0.58, 0.13)
			var hl:= clampf(1.0 - (p - Vector2(-4.0, -4.0)).length() / 7.0, 0.0, 1.0)
			col = col.lerp(Color(1.0, 0.97, 0.8), hl * 0.7)
			col.a = a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _tex_glint() -> ImageTexture:
	var n:= 32
	var img:= Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p:= (Vector2(x + 0.5, y + 0.5) - Vector2(n, n) * 0.5) / (n * 0.5)
			var v:= exp(- absf(p.x) * 14.0) * (1.0 - absf(p.y)) + exp(- absf(p.y) * 14.0) * (1.0 - absf(p.x)) + exp(- p.length_squared() * 20.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(v, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func _tex_streak() -> ImageTexture:
	var w:= 8
	var h:= 48
	var img:= Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var across:= clampf(1.0 - absf(x + 0.5 - w * 0.5) / (w * 0.5), 0.0, 1.0)
			var along:= sin(PI * (y + 0.5) / h)
			img.set_pixel(x, y, Color(1, 1, 1, across * across * along))
	return ImageTexture.create_from_image(img)


func play(id: String, then:= Callable()) -> void:
	_id = id
	_then = then
	mouse_filter = Control.MOUSE_FILTER_STOP if then.is_valid() else Control.MOUSE_FILTER_IGNORE
	_t = 0.0
	_fading = 0.0
	_revealed = false
	_running = true
	visible = true
	set_process(true)


	move_to_front()
	_chest_failed = false
	_ensure_chest()
	_prize_failed = false
	_prize_path = PRIZES.get(id, "")
	if _prize != null:
		_prize.queue_free()
		_prize = null
	_ensure_prize()
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_plan_roll()
	_icon.texture = null
	_icon.modulate.a = 0.0
	_shine_mat.set_shader_parameter("silhouette", 1.0)
	_title.text = tr("FREE GIFT")
	_name.text = Cfg.upper(BuildCatalog.display_name(id))
	_price.text = "$%d" % int(round(list_price(id)))
	_stamp_label.text = tr("FREE")
	_holds = then.is_valid()
	if _holds:
		_hide_hud(true)
		var mark:= FileAccess.open(OPEN_MARK, FileAccess.WRITE)
		if mark != null:
			mark.store_string(id)
			mark.close()
	_take_hover = false
	_take_glow = 0.0
	_take_press = 0.0
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	if _holds:

		_hint.text = ""
		_take_label.text = Cfg.upper(tr("Take it"))
		_take_keys.text = tr("or press %s") % ("%s / %s" % [InputSetup.hint("interact"),
			InputSetup.hint("free_mouse")])
	else:
		_hint.text = tr("Press %s to place it") % InputSetup.hint("build_catalog")
		_take_keys.text = ""
	_shine_mat.set_shader_parameter("sweep", -1.0)
	for p: CPUParticles2D in _all_particles():
		p.emitting = false
		p.restart()
		p.emitting = false
	_pose_chest()
	Audio.music_duck(MUSIC_UNDER, 0.6)


static func list_price(id: String) -> float:
	var build:= 0.0
	match id:
		"rake":
			build = Cfg.RAKE_COST
		"cabinet":
			build = Cfg.CABINET_COST
		"pole":


			return Cfg.POLE_COST
		_:
			return 0.0
	var card:= BuildCatalog.unlock_of(id)
	return build + (TechTree.cost_at(card, 0) if card != "" else 0.0)


func is_playing() -> bool:
	return _running


func is_holding() -> bool:
	return _running and _fading <= 0.0 and _then.is_valid()


func dismiss() -> void:
	if _running and _fading <= 0.0:
		_begin_fade()


func _input(event: InputEvent) -> void:
	if not _running or _fading > 0.0:
		return
	if _then.is_valid():
		if not (event is InputEventKey or event is InputEventMouseButton
				or event is InputEventJoypadButton or event is InputEventAction):
			return
		get_viewport().set_input_as_handled()
		if not event.is_pressed() or event.is_echo():
			return
		if event.is_action_pressed("interact") or event.is_action_pressed("free_mouse"):
			_take_it()
			return
		var mb:= event as InputEventMouseButton
		if mb != null and _t >= T_HINT and mb.button_index == MOUSE_BUTTON_LEFT and _take_rect(size.y / REF_H).has_point(make_input_local(mb).position):
			_take_it()
		return
	if event.is_action_pressed("build_catalog") and _t > T_REVEAL:
		dismiss()


func _take_it() -> void:
	var then:= _then
	_then = Callable()
	_take_press = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW


	Audio.stop_card()
	Audio.play_card("ui_select", -7.0)

	_clear_mark()
	_hide_hud(false)
	_begin_fade()
	then.call()


func _hide_hud(on: bool) -> void:
	if hud_layer == null or on == _hid_hud:
		return
	_hid_hud = on
	hud_layer.visible = not on


func _all_particles() -> Array [CPUParticles2D]:
	return [_coins, _glints, _sparks, _streaks, _shards, _stamp_sparks]


func _plan_roll() -> void:
	_roll_ids.clear()
	_roll_times.clear()
	_roll_next = 0
	var gift_tile: Variant = CatalogPanel.BUILD_ICON_TILES.get(_id)
	var seen:= { }
	var pool: Array [String] = []
	for id: Variant in BuildCatalog.ordered_ids():
		var sid:= str(id)
		if not sid in ROLL_POOL or not CatalogPanel.BUILD_ICON_TILES.has(sid):
			continue
		var tile: Vector2i = CatalogPanel.BUILD_ICON_TILES [sid]
		if tile == gift_tile or seen.has(tile):
			continue
		seen [tile] = true
		pool.append(sid)
	for i in range(pool.size() - 1, 0, -1):
		var j:= _rng.randi_range(0, i)
		var keep:= pool [i]
		pool [i] = pool [j]
		pool [j] = keep
	var gaps: Array [float] = []
	var total:= 0.0
	for i in ROLL_STEPS:
		var k:= float(i) / float(ROLL_STEPS - 1)
		var gap:= lerpf(ROLL_FIRST, ROLL_LAST, k * k)
		gaps.append(gap)
		total += gap
	var fit:= (T_REVEAL - T_ROLL) / total
	var at:= T_ROLL
	for i in ROLL_STEPS:
		_roll_times.append(at)
		_roll_ids.append(pool [i % pool.size()] if not pool.is_empty() else _id)
		at += gaps [i] * fit


func _process(delta: float) -> void:
	var was:= _t
	_t += delta
	if _fading > 0.0:
		_fading += delta
	elif _t >= T_HOLD and not _then.is_valid():

		_begin_fade()
	if _fading > T_FADE:
		_stop()
		return


	if _fading <= 0.0:
		_beats(was)
	_pose_chest()
	_hover_take(delta)
	_layout()
	_redraw_layers()


func _begin_fade() -> void:
	_fading = 0.001
	_coins.emitting = false
	_glints.emitting = false
	Audio.ui_loop_stop("chest_aura", T_FADE + 0.4)
	Audio.music_unduck()


func _stop() -> void:
	_running = false
	_then = Callable()
	if _holds:
		_clear_mark()
	_hide_hud(false)
	_holds = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	visible = false
	set_process(false)
	for p: CPUParticles2D in _all_particles():
		p.emitting = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.size = Vector2i(2, 2)
	_drop_chest()
	finished.emit()


func _beats(was: float) -> void:


	if _crossed(was, T_CHEST):
		Audio.play_card("ui_open", -4.0)
	if _crossed(was, T_TUMBLE):
		Audio.play_card("chest_tumble", 0.0)
	for i in HOPS.size():
		var h: Array = HOPS [i]
		if _crossed(was, float(h [0]) + float(h [1])):
			Audio.play_card("chest_knock", lerpf(-6.0, -2.0, float(i) / float(HOPS.size() - 1)))
	if _crossed(was, T_CRACK):
		Audio.play_card("chest_open", -3.0)
	if _crossed(was, T_BURST):
		_burst()
	if _crossed(was, T_ROLL):
		Audio.play_card("chest_spin", 0.0)
	while _roll_next < _roll_times.size() and _t >= _roll_times [_roll_next]:
		_roll_step()
	if _crossed(was, T_REVEAL):
		_reveal()
	if _crossed(was, T_REVEAL + 0.25):


		Audio.ui_loop_start("chest_aura", -6.0, 1.2)
	if _crossed(was, T_STAMP):
		_slam()


func _crossed(was: float, at: float) -> bool:
	return was < at and _t >= at


func _burst() -> void:
	var s:= size.y / REF_H
	var mouth:= _mouth(s)
	_aim(_sparks, mouth, s, 380.0, 1000.0, 55.0, 900.0)
	_sparks.scale_amount_min = 0.2 * s
	_sparks.scale_amount_max = 0.6 * s
	_sparks.restart()
	_sparks.emitting = true
	var mid:= _centre()
	for p: CPUParticles2D in [_coins, _glints]:
		p.position = mid + Vector2(0.0, -0.02 * CARD_H * s)
		p.emission_rect_extents = Vector2(CARD_W * 0.42, CARD_H * 0.34) * s
		p.initial_velocity_min = 12.0 * s
		p.initial_velocity_max = 48.0 * s
		p.gravity = Vector2(0.0, -14.0 * s)
		p.emitting = true
	_coins.scale_amount_min = 0.55 * s
	_coins.scale_amount_max = 0.95 * s
	_glints.scale_amount_min = 0.35 * s
	_glints.scale_amount_max = 0.85 * s


func _roll_step() -> void:
	var i:= _roll_next
	_roll_next += 1
	_show(_roll_ids [i])
	_roll_since = _roll_times [i]
	_roll_tilt = _rng.randf_range(-12.0, 12.0)


func _show(id: String) -> void:
	var tex:= CatalogPanel._icon_for(id)
	_icon.texture = tex
	if tex == null or tex.atlas == null:
		return
	var sheet:= Vector2(tex.atlas.get_size())
	_shine_mat.set_shader_parameter("region", Vector4(tex.region.position.x / sheet.x,
		tex.region.position.y / sheet.y, tex.region.size.x / sheet.x, tex.region.size.y / sheet.y))


func _reveal() -> void:
	_revealed = true
	_show(_id)

	_shine_mat.set_shader_parameter("silhouette", 0.0)
	var s:= size.y / REF_H
	var mouth:= _mouth(s)
	var home:= _centre() + Vector2(0.0, CARD_H * s * Y_ICON)
	_aim(_streaks, home + Vector2(0.0, ICON * 0.3 * s), s, 700.0, 1500.0, 20.0, 0.0)
	_streaks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_streaks.emission_rect_extents = Vector2(ICON * 0.4, 20.0) * s
	_streaks.damping_min = 900.0 * s
	_streaks.damping_max = 1500.0 * s
	_streaks.scale_amount_min = 0.7 * s
	_streaks.scale_amount_max = 1.3 * s
	_streaks.restart()
	_streaks.emitting = true
	_aim(_shards, mouth, s, 600.0, 1300.0, 95.0, 0.0)
	_shards.damping_min = 1600.0 * s
	_shards.damping_max = 2400.0 * s
	_shards.scale_amount_min = 0.5 * s
	_shards.scale_amount_max = 0.9 * s
	_shards.restart()
	_shards.emitting = true
	_splash.clear()
	for i in 18:
		_splash.append(Vector3(_rng.randf_range(PI - 0.15, TAU + 0.15),
			_rng.randf_range(90.0, 260.0), _rng.randf_range(5.0, 11.0)))


func _aim(p: CPUParticles2D, at: Vector2, s: float, v_min: float, v_max: float,
		spread: float, grav: float) -> void:
	p.position = at
	p.direction = Vector2(0, -1)
	p.spread = spread
	p.initial_velocity_min = v_min * s
	p.initial_velocity_max = v_max * s
	p.gravity = Vector2(0, grav * s)
	p.damping_min = 180.0 * s
	p.damping_max = 320.0 * s
	p.scale_amount_min = 0.25 * s
	p.scale_amount_max = 0.8 * s


func _slam() -> void:
	var s:= size.y / REF_H
	Audio.play_card("coins", -3.0)
	_aim(_stamp_sparks, _stamp_centre(s), s, 220.0, 620.0, 180.0, 300.0)
	_stamp_sparks.restart()
	_stamp_sparks.emitting = true


func _fade() -> float:
	return 1.0 - (smoothstep(0.0, T_FADE, _fading) if _fading > 0.0 else 0.0)


func _jolt(s: float) -> Vector2:
	var k:= _t - T_STAMP
	if k < 0.0 or k > 0.28:
		return Vector2.ZERO
	var amp:= 9.0 * s * (1.0 - k / 0.28)
	return Vector2(sin(k * 90.0), cos(k * 77.0)) * amp


func _stamp_centre(s: float) -> Vector2:
	return _centre() + Vector2(0, CARD_H * s * Y_STAMP)


func _mouth(s: float) -> Vector2:
	return _centre() + _jolt(s) + Vector2(0.0, CARD_H * s * Y_MOUTH)


func _card_rect(mid: Vector2, s: float) -> Rect2:
	return Rect2(mid - Vector2(CARD_W, CARD_H) * s * 0.5, Vector2(CARD_W, CARD_H) * s)


func _pose_chest() -> void:
	_ensure_chest()
	if _chest == null:
		return
	var t:= _t

	var pk:= clampf((t - T_CHEST) / 0.5, 0.0, 1.0)
	_pivot.visible = pk > 0.0
	var grow:= maxf(_back_out(pk), 0.001)
	var yaw:= deg_to_rad(-40.0) * exp(- pk * 5.0) * cos(pk * 9.0) + sin(t * 0.9) * 0.06 * pk
	var roll:= deg_to_rad(14.0) * exp(- pk * 5.0) * sin(pk * 12.0)
	var lift:= 0.0
	var sq:= Vector3.ONE
	for i in HOPS.size():
		var h: Array = HOPS [i]
		var u:= (t - float(h [0])) / float(h [1])
		if u >= 0.0 and u <= 1.0:
			lift = float(h [2]) * sin(u * PI)
			roll += deg_to_rad(5.0 + 2.0 * i) * sin(u * PI) * (1.0 if i % 2 == 0 else -1.0)
		elif u > 1.0 and u < 1.6:

			var q:= (u - 1.0) / 0.6
			var a:= 0.06 * sin(q * PI) * (1.0 - q)
			sq = Vector3(1.0 + a, 1.0 - a, 1.0 + a)
	if t >= T_CRACK and t < T_BURST:

		roll += deg_to_rad(1.3) * sin(t * 71.0)
		yaw += deg_to_rad(0.8) * sin(t * 53.0)
	if t >= T_BURST:
		var b:= t - T_BURST
		var a:= 0.1 * exp(- b * 9.0) * cos(b * 22.0)
		sq = Vector3(1.0 + a * 0.6, 1.0 - a, 1.0 + a * 0.6)
	if t >= T_REVEAL:
		var r:= t - T_REVEAL
		var a:= 0.06 * exp(- r * 10.0) * cos(r * 26.0)
		sq *= Vector3(1.0 + a * 0.5, 1.0 - a, 1.0 + a * 0.5)
	_pivot.transform = Transform3D(Basis.from_euler(Vector3(0.0, yaw, roll))
		* Basis.from_scale(sq * grow), Vector3(0.0, lift, 0.0))


	var ang:= 0.0
	var crack:= 0.0
	if t >= T_CRACK and t < T_BURST:
		crack = clampf((t - T_CRACK) / (T_BURST - T_CRACK), 0.0, 1.0)
		ang = LID_CRACK * smoothstep(0.0, 1.0, crack) + 1.5 * sin(t * 60.0) * crack
	elif t >= T_BURST:
		var u:= t - T_BURST
		ang = LID_OPEN - (LID_OPEN - LID_CRACK) * exp(- u * 9.0) * cos(u * 11.0)


	var lock_t:= _beat_curve(LOCK_BEATS, t)
	var hasp_t:= lock_t
	if t >= T_CRACK:
		var up:= clampf(ang / LID_OPEN, 0.0, 1.0)
		hasp_t = maxf(lock_t, lerpf(LID_CLIP_SHUT, LID_CLIP_OPEN, up))
		if t >= T_BURST:
			var flop:= clampf((t - T_BURST - 0.08) / 0.35, 0.0, 1.0)
			hasp_t = lerpf(hasp_t, HASP_CLIP_FLOP, smoothstep(0.0, 1.0, flop))
	var last: Array = LOCK_BEATS [LOCK_BEATS.size() - 1]
	var gone:= clampf((t - float(last [0])) / LOCK_GONE, 0.0, 1.0)
	_pose_bones(lock_t, hasp_t, ang, gone)


	var reach:= 0.0
	var gain:= 0.0
	var inner:= 1.0 * crack
	if t >= T_BURST:
		var u:= t - T_BURST
		reach = 1.0 - exp(- u * 12.0)
		gain = 1.0 + 0.6 * exp(- u * 6.0)
		inner = 1.1 + 1.6 * exp(- u * 3.0)
	if t >= T_REVEAL:
		var r:= t - T_REVEAL
		gain *= clampf(1.0 - r / 0.35, 0.0, 1.0)
		inner = lerpf(inner, 0.7, clampf(r / 0.6, 0.0, 1.0))
	var fade:= _fade()
	_inner.light_energy = inner * fade
	for i in _beam_mats.size():
		var wob:= 1.0 if i == 0 else 0.88 + 0.12 * sin(t * (5.0 + i) + i * 1.7)
		_beam_mats [i].set_shader_parameter("reach", reach * wob)
		_beam_mats [i].set_shader_parameter("gain", gain * fade)
	_pose_prize()


func _pose_prize() -> void:
	_ensure_prize()
	if _prize == null:
		return
	var t:= _t
	_prize.visible = t >= T_ROLL
	if t < T_REVEAL:
		_prize.transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.2), PRIZE_HIDDEN)
		return
	var age:= t - T_REVEAL
	var e:= _back_out(clampf(age / 0.36, 0.0, 1.0))
	var punch:= 1.0 + 0.25 * sin(clampf(age / 0.3, 0.0, 1.0) * PI)
	var settle:= clampf(age / 0.6, 0.0, 1.0)
	var home:= PRIZE_AT
	home.y = minf(home.y, PRIZE_TOP - _prize_half_h)
	var at:= PRIZE_HIDDEN.lerp(home, e) + Vector3(0.0, sin(age * 2.3) * 0.03 * settle, 0.0)
	var yaw:= deg_to_rad(-30.0) + age * PRIZE_TURN
	var tilt:= deg_to_rad(sin(age * 1.4) * 4.0) * settle
	var k:= maxf(lerpf(0.2, 1.0, e) * punch, 0.001)
	_prize.transform = Transform3D(Basis.from_euler(Vector3(tilt, yaw, 0.0))
		* Basis.from_scale(Vector3.ONE * k), at)


func _prize_on_screen() -> Vector2:
	var p:= _cam.unproject_position(_prize.global_position)
	return _chest_view.position + p * (_chest_view.size / Vector2(_vp.size))


func _layout() -> void:
	var s:= size.y / REF_H
	var mid:= _centre() + _jolt(s)
	var fade:= _fade()


	var card:= _card_rect(mid, s)
	_chest_view.position = card.position
	_chest_view.size = card.size
	var want:= Vector2i(maxi(int(round(card.size.x)), 64), maxi(int(round(card.size.y)), 64))
	if _vp.size != want:
		_vp.size = want
	_chest_view.visible = _t >= T_CHEST
	_chest_view.modulate.a = fade


	var mouth:= _mouth(s)
	var home:= mid + Vector2(0.0, CARD_H * s * Y_ICON)
	if not _revealed:
		if _roll_next == 0:
			_icon.modulate.a = 0.0
		else:
			var pk:= clampf((_t - _roll_since) / 0.07, 0.0, 1.0)
			var side:= ROLL_ICON * s
			_icon.size = Vector2(side, side)
			_icon.pivot_offset = _icon.size * 0.5
			_icon.position = mouth - Vector2(side * 0.5, side * 0.72)
			_icon.scale = Vector2.ONE * lerpf(0.7, 1.0, _back_out(pk))
			_icon.rotation = deg_to_rad(_roll_tilt)
			_icon.modulate.a = fade
			_icon_at = _icon.position + _icon.size * 0.5
	else:
		var age:= _t - T_REVEAL
		var k:= clampf(age / 0.34, 0.0, 1.0)
		var e:= _back_out(k)
		var settle:= clampf(age / 0.6, 0.0, 1.0)
		var start:= mouth - Vector2(0.0, ROLL_ICON * s * 0.22)
		var bob:= Vector2(0.0, sin(age * 2.3) * 6.0 * s) * settle
		var c:= start.lerp(home, e) + bob
		var side:= ICON * s
		_icon.size = Vector2(side, side)
		_icon.pivot_offset = _icon.size * 0.5
		_icon.position = c - _icon.size * 0.5
		var punch:= 1.0 + 0.35 * sin(clampf(age / 0.3, 0.0, 1.0) * PI)
		_icon.scale = Vector2.ONE * lerpf(ROLL_ICON / ICON, 1.0, e) * punch
		_icon.rotation = deg_to_rad(sin(age * 1.4) * 3.0) * settle
		_icon.modulate.a = fade
		_icon_at = c


		if _prize != null:
			_icon.modulate.a = 0.0
			_icon_at = _prize_on_screen()

	var since:= _t - (T_REVEAL + 0.45)
	var sweep:= -1.0
	if since >= 0.0:
		sweep = fmod(since, SHINE_EVERY) / 0.8 * 1.6 - 0.4
	_shine_mat.set_shader_parameter("sweep", sweep)


	var age:= maxf(_t - T_REVEAL, 0.0)
	var land:= 1.0 - pow(1.0 - clampf(age / 0.7, 0.0, 1.0), 3.0)
	var on:= clampf(age / 0.25, 0.0, 1.0) * fade if _revealed else 0.0
	_place_sun(_sun_a, ICON * 2.9 * s * lerpf(2.2, 1.0, land) * (1.0 + 0.04 * sin(age * 2.2)),
		age * 0.22, on * 0.95)
	_place_sun(_sun_b, ICON * 2.0 * s * lerpf(1.7, 1.0, land) * (1.0 + 0.05 * sin(age * 2.9 + 1.3)),
		0.13 - age * 0.35, on * 0.55)


	var top:= mid.y - CARD_H * s * 0.5
	_drop(_title, T_TITLE, top + 22.0 * s, s, fade, 1.5)
	_drop(_name, T_NAME, mid.y + CARD_H * s * Y_NAME, s, fade, 1.0)
	_drop(_price, T_PRICE, mid.y + CARD_H * s * Y_PRICE, s, fade, 1.0)
	var ht:= clampf((_t - T_HINT) / 0.4, 0.0, 1.0)
	_hint.position = Vector2(0, mid.y + CARD_H * s * Y_HINT)
	_hint.size = Vector2(size.x, 40.0 * s)
	_hint.modulate.a = ht * fade * 0.92


	var font:= _stamp_label.get_theme_font("font")
	var word:= font.get_string_size(_stamp_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_stamp_label.get_theme_font_size("font_size")).x
	_banner_w = maxf(BANNER_W, word + 90.0)
	var st:= clampf((_t - T_STAMP) / 0.16, 0.0, 1.0)
	_stamp_label.size = Vector2(_banner_w, BANNER_H)
	_stamp_label.pivot_offset = _stamp_label.size * 0.5
	_stamp_label.position = _stamp_centre(s) + _jolt(s) + _banner_bob(s) - _stamp_label.size * 0.5
	_stamp_label.scale = Vector2.ONE * s * _banner_grow(st) * _banner_beat()
	_stamp_label.rotation = _banner_turn(st) + _banner_sway()
	_stamp_label.modulate.a = _banner_alpha(st) * fade


	var tr_:= _take_rect(s)
	_take_label.size = Vector2(TAKE_W, TAKE_H)
	_take_label.pivot_offset = _take_label.size * 0.5
	_take_label.position = tr_.get_center() - _take_label.size * 0.5 + Vector2(0.0, -1.5 * s)
	_take_label.scale = Vector2.ONE * s * _take_grow()
	_take_label.modulate.a = _take_alpha()
	_take_keys.position = Vector2(0.0, tr_.end.y + 8.0 * s)
	_take_keys.size = Vector2(size.x, 30.0 * s)
	_take_keys.modulate.a = _take_alpha() * 0.85


static func _banner_grow(st: float) -> float:
	return lerpf(2.6, 1.0, st * st)


static func _banner_turn(st: float) -> float:
	return deg_to_rad(lerpf(-22.0, -6.0, st))


const BANNER_BEAT:= 2.6


func _banner_since() -> float:
	return _t - T_STAMP - 0.35


func _banner_live() -> float:
	return clampf((_t - T_STAMP - 0.16) / 0.6, 0.0, 1.0)


func _banner_bob(s: float) -> Vector2:
	return Vector2(0.0, sin((_t - T_STAMP) * 2.2) * 5.0 * s * _banner_live())


func _banner_sway() -> float:
	return deg_to_rad(sin((_t - T_STAMP) * 1.7) * 2.2) * _banner_live()


func _banner_beat() -> float:
	var since:= _banner_since()
	if since <= 0.0:
		return 1.0
	var k:= fmod(since, BANNER_BEAT) / 0.32
	return 1.0 + 0.08 * sin(k * PI) if k < 1.0 else 1.0


func _banner_alpha(st: float) -> float:
	return 0.0 if _t < T_STAMP else clampf(st * 2.0, 0.0, 1.0)


func _place_sun(r: TextureRect, side: float, turn: float, alpha: float) -> void:
	r.size = Vector2(side, side)
	r.pivot_offset = r.size * 0.5
	r.position = _icon_at - r.size * 0.5
	r.rotation = turn
	r.modulate.a = alpha


func _drop(l: Label, at: float, y: float, s: float, fade: float, grow: float) -> void:
	var t:= clampf((_t - at) / 0.3, 0.0, 1.0)
	var k:= _back_out(t)
	l.size = Vector2(size.x, 64.0 * s)
	l.pivot_offset = Vector2(size.x * 0.5, 32.0 * s)
	l.position = Vector2(0, y - (1.0 - t) * 18.0 * s)
	l.scale = Vector2.ONE * lerpf(grow, 1.0, k)
	l.modulate.a = clampf(t * 2.0, 0.0, 1.0) * fade


static func _beat_curve(pairs: Array, x: float) -> float:
	var first: Array = pairs [0]
	if x <= float(first [0]):
		return float(first [1])
	for i in range(1, pairs.size()):
		var a: Array = pairs [i - 1]
		var b: Array = pairs [i]
		if x < float(b [0]):
			return lerpf(float(a [1]), float(b [1]), (x - float(a [0])) / (float(b [0]) - float(a [0])))
	return float(pairs [pairs.size() - 1] [1])


static func _back_out(t: float) -> float:
	var c:= 1.70158
	var u:= t - 1.0
	return 1.0 + (c + 1.0) * u * u * u + c * u * u


var _c: Control
var _back: Control
var _front: Control
var _over: Control


func _layer(layer_name: String) -> Control:
	var c:= Control.new()
	c.name = layer_name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	return c


func _redraw_layers() -> void:
	_back.queue_redraw()
	_front.queue_redraw()
	_over.queue_redraw()
	_banner.queue_redraw()
	_take.queue_redraw()


func _draw_back() -> void:
	if not _running:
		return
	_c = _back
	var dim:= smoothstep(0.0, 0.3, _t) * DIM_ALPHA * _fade()
	_c.draw_rect(Rect2(Vector2.ZERO, size), Color(COL_DIM.r, COL_DIM.g, COL_DIM.b, dim))


func _draw_front() -> void:
	if not _running:
		return
	_c = _front
	var s:= size.y / REF_H
	_draw_card(_centre() + _jolt(s), s, _fade())


func _draw_over() -> void:
	if not _running:
		return
	_c = _over
	var s:= size.y / REF_H
	_draw_strike(s, _fade())
	if _revealed:
		_draw_reveal(s)


func _draw_card(mid: Vector2, s: float, fade: float) -> void:
	var hk:= smoothstep(0.0, 1.0, clampf(_t / T_LINE, 0.0, 1.0))
	var wk:= smoothstep(0.0, 1.0, clampf((_t - T_LINE) / T_OPEN, 0.0, 1.0))
	if hk <= 0.0:
		return
	var h:= CARD_H * s * hk
	var w:= maxf(CARD_W * s * wk, 2.0 * s)
	var card:= Rect2(mid - Vector2(w, h) * 0.5, Vector2(w, h))
	_c.draw_rect(card, Color(COL_CARD.r, COL_CARD.g, COL_CARD.b, COL_CARD.a * fade))
	_draw_frame(card, mid, s, fade, wk)


	if _revealed:
		var on:= clampf((_t - T_REVEAL) / 0.4, 0.0, 1.0)
		var reach:= ICON * 0.62 * s
		for i in 32:
			var k:= 1.0 - float(i) / 32.0
			_c.draw_circle(_icon_at, reach * (0.2 + 0.8 * k),
				Color(1.0, 0.9, 0.66, 0.03 * on * fade))


func _draw_frame(card: Rect2, mid: Vector2, s: float, fade: float, wk: float) -> void:
	var line:= maxf(4.5 * s, 2.0)
	for i in 4:
		var g:= float(i + 1)
		_c.draw_rect(card.grow(g * 2.5 * s), Color(COL_GOLD_MID, 0.06 * (1.0 - g / 5.0) * fade),
			false, line * 1.4)
	var corners: Array [Vector2] = [card.position, Vector2(card.end.x, card.position.y), card.end,
		Vector2(card.position.x, card.end.y), card.position]
	var per:= 2.0 * (card.size.x + card.size.y)
	var head:= fmod(_t / GLINT_LAP, 1.0) * per
	var run:= 0.0
	var step:= 10.0 * s
	for e in 4:
		var a:= corners [e]
		var b:= corners [e + 1]
		var length:= a.distance_to(b)
		var n:= maxi(int(ceil(length / step)), 1)
		for i in n:
			var p0:= a.lerp(b, float(i) / n)
			var p1:= a.lerp(b, float(i + 1) / n)
			var d:= run + length * (float(i) + 0.5) / n
			_c.draw_line(p0, p1, Color(_gold_at(d, head, per, (p0 + p1) * 0.5, card, s), fade), line)

		_c.draw_rect(Rect2(a - Vector2.ONE * line * 0.5, Vector2.ONE * line),
			Color(_gold_at(run, head, per, a, card, s), fade))
		run += length


	_c.draw_rect(card.grow(line * 0.5), Color(COL_GOLD_HI, 0.45 * fade), false, maxf(1.0 * s, 1.0))
	_c.draw_rect(card.grow(-6.5 * s), Color(COL_GOLD_DEEP, 0.75 * fade), false, maxf(1.0 * s, 1.0))
	if wk < 0.99:
		return


	var over:= 6.0 * s
	var arm:= 46.0 * s
	var band:= 16.0 * s
	var edge:= maxf(1.2 * s, 1.0)
	var rim:= Color(COL_GOLD_DEEP.darkened(0.45), fade)
	for corner: Vector2 in [card.position, Vector2(card.end.x, card.position.y),
			Vector2(card.position.x, card.end.y), card.end]:
		var sx:= 1.0 if corner.x < mid.x else -1.0
		var sy:= 1.0 if corner.y < mid.y else -1.0
		var at:= func(u: float, v: float) -> Vector2:
			return corner + Vector2(sx * u, sy * v)
		var u:= ((corner.x - card.position.x) / maxf(card.size.x, 1.0)
			+ (corner.y - card.position.y) / maxf(card.size.y, 1.0)) * 0.5
		var plate:= PackedVector2Array([at.call(- over, - over), at.call(arm, - over),
			at.call(arm, band - over), at.call(band - over, band - over),
			at.call(band - over, arm), at.call(- over, arm)])
		_fill(plate, Color(COL_GOLD_MID.lerp(COL_GOLD_DEEP, 0.2 + 0.45 * u), fade))
		var ring:= plate.duplicate()
		ring.append(plate [0])
		_c.draw_polyline(ring, rim, edge, true)

		var lip:= over - edge
		_c.draw_polyline(PackedVector2Array([at.call(- lip, arm - edge), at.call(- lip, - lip),
			at.call(arm - edge, - lip)]), Color(COL_GOLD_HI, (0.8 - 0.4 * u) * fade), edge, true)
		var half:= band * 0.5 - over
		for p: Vector2 in [at.call(half, half), at.call(arm - band * 0.5, half),
				at.call(half, arm - band * 0.5)]:
			_draw_rivet(p, s, fade)


func _draw_rivet(p: Vector2, s: float, fade: float) -> void:
	_c.draw_circle(p, 3.6 * s, Color(COL_GOLD_DEEP.darkened(0.5), fade), true, -1.0, true)
	_c.draw_circle(p, 2.7 * s, Color(COL_GOLD_MID, fade), true, -1.0, true)
	_c.draw_circle(p - Vector2.ONE * 0.9 * s, 1.1 * s, Color(COL_GOLD_HI, fade), true, -1.0, true)


func _gold_at(d: float, head: float, per: float, p: Vector2, card: Rect2, s: float) -> Color:
	var u:= ((p.x - card.position.x) / maxf(card.size.x, 1.0)
		+ (p.y - card.position.y) / maxf(card.size.y, 1.0)) * 0.5
	var c:= COL_GOLD_MID.lerp(COL_GOLD_DEEP, clampf(u * 1.3 - 0.15, 0.0, 1.0))
	var near:= absf(fposmod(d - head + per * 0.5, per) - per * 0.5)
	var far:= absf(fposmod(d - head, per) - per * 0.5)
	var glint:= exp(- pow(near / (70.0 * s), 2.0)) + 0.45 * exp(- pow(far / (55.0 * s), 2.0))
	return c.lerp(COL_GOLD_HI, clampf(glint, 0.0, 1.0))


func _draw_banner() -> void:
	if not _running or _t < T_STAMP:
		return
	_c = _banner
	var s:= size.y / REF_H
	var st:= clampf((_t - T_STAMP) / 0.16, 0.0, 1.0)
	var a:= _banner_alpha(st) * _fade()
	_c.draw_set_transform(_stamp_centre(s) + _jolt(s) + _banner_bob(s),
		_banner_turn(st) + _banner_sway(), Vector2.ONE * s * _banner_grow(st) * _banner_beat())
	var w:= _banner_w * 0.5
	var h:= BANNER_H * 0.5
	var drop:= 12.0
	var body:= PackedVector2Array([Vector2(- w, - h), Vector2(w, - h), Vector2(w, h), Vector2(- w, h)])
	var shade:= PackedVector2Array()
	for p in body:
		shade.append(p + Vector2(0.0, 8.0))
	_fill(shade, Color(0.0, 0.0, 0.0, 0.35 * a))
	for side: float in [-1.0, 1.0]:
		var near:= side * (w - 20.0)
		var far:= side * (w + BANNER_TAIL)
		_fill(PackedVector2Array([Vector2(near, - h + drop), Vector2(far, - h + drop),
			Vector2(far - side * 16.0, drop), Vector2(far, h + drop), Vector2(near, h + drop)]),
			Color(COL_BANNER_TAIL, a))
		_fill(PackedVector2Array([Vector2(side * (w - 20.0), h), Vector2(side * w, h),
			Vector2(side * w, h + drop)]), Color(COL_BANNER_FOLD, a))
	var top:= Color(COL_BANNER_TOP, a)
	var low:= Color(COL_BANNER_LOW, a)
	_c.draw_polygon(body, PackedColorArray([top, top, low, low]))
	var ring:= body.duplicate()
	ring.append(body [0])
	_c.draw_polyline_colors(ring, PackedColorArray([top, top, low, low, top]), 1.0, true)
	_c.draw_line(Vector2(- w, - h + 1.5), Vector2(w, - h + 1.5), Color(1.0, 0.75, 0.75, 0.45 * a),
		1.5, true)
	for y: float in [- h + 7.0, h - 7.0]:
		_c.draw_line(Vector2(- w + 8.0, y), Vector2(w - 8.0, y), Color(COL_TRIM, 0.9 * a), 2.5, true)

	var since:= _banner_since()
	if since > 0.0:
		var k:= fmod(since, BANNER_BEAT) / 0.55
		if k < 1.0:
			_glint(body, lerpf(- w - 40.0, w + 40.0, k), h, 0.8 * a)
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _centre() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5 - CARD_LIFT * size.y / REF_H)


func _take_rect(s: float) -> Rect2:
	var sz:= Vector2(TAKE_W, TAKE_H) * s
	var c:= _centre() + Vector2(0.0, (CARD_H * 0.5 + TAKE_BELOW) * s)
	return Rect2(c - sz * 0.5, sz)


func _take_in() -> float:
	return clampf((_t - T_HINT) / 0.35, 0.0, 1.0) if _holds else 0.0


func _take_alpha() -> float:
	return clampf(_take_in() * 2.0, 0.0, 1.0) * _fade()


func _take_grow() -> float:
	return lerpf(0.55, 1.0, _back_out(_take_in())) * (1.0 + 0.05 * _take_glow) * (1.0 - 0.08 * sin(clampf(1.0 - _take_press, 0.0, 1.0) * PI) * _take_press)


func _hover_take(delta: float) -> void:
	_take_press = maxf(_take_press - delta * 4.0, 0.0)
	var over:= false
	if is_holding() and _t >= T_HINT:
		over = _take_rect(size.y / REF_H).has_point(get_local_mouse_position())
	if over != _take_hover:
		_take_hover = over
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over else Control.CURSOR_ARROW
		if over:
			Audio.play("ui_tick", -10.0)
	_take_glow = move_toward(_take_glow, 1.0 if _take_hover else 0.0, delta * 7.0)


func _draw_take() -> void:
	if not _running or not _holds or _take_in() <= 0.0:
		return
	_c = _take
	var s:= size.y / REF_H
	var a:= _take_alpha()
	var r:= _take_rect(s)
	_c.draw_set_transform(r.get_center(), 0.0, Vector2.ONE * s * _take_grow())
	var w:= TAKE_W * 0.5
	var h:= TAKE_H * 0.5
	var breathe:= 0.5 + 0.5 * sin(_t * 3.6)


	for i in 7:
		var g:= float(i + 1) * 3.2
		_c.draw_rect(Rect2(- w - g, - h - g, 2.0 * (w + g), 2.0 * (h + g)), Color(COL_GOLD_MID,
			(0.05 + 0.03 * breathe + 0.05 * _take_glow) * (1.0 - float(i) / 7.0) * a))

	_c.draw_rect(Rect2(- w, - h + 6.0, 2.0 * w, 2.0 * h), Color(0.0, 0.0, 0.0, 0.4 * a))


	var body:= PackedVector2Array([Vector2(- w, - h), Vector2(w, - h), Vector2(w, 0.0),
		Vector2(w, h), Vector2(- w, h), Vector2(- w, 0.0)])
	var lift:= func(c: Color) -> Color: return Color(c.lerp(COL_GOLD_HI, 0.25 * _take_glow), a)
	var hi: Color = lift.call(COL_GOLD_HI)
	var mid: Color = lift.call(COL_GOLD_MID)
	var deep: Color = lift.call(COL_GOLD_DEEP)
	_c.draw_polygon(body, PackedColorArray([hi, hi, mid, deep, deep, mid]))


	var since:= _t - T_HINT - 0.5
	if since > 0.0:
		var k:= fmod(since, 2.2) / 0.5
		if k < 1.0:
			_glint(body, lerpf(- w - 40.0, w + 40.0, k), h, a)

	_c.draw_line(Vector2(- w + 3.0, - h + 3.5), Vector2(w - 3.0, - h + 3.5),
		Color(1.0, 1.0, 0.92, 0.55 * a), 2.0)


	_c.draw_rect(Rect2(- w, - h, 2.0 * w, 2.0 * h), Color(COL_GOLD_DEEP.darkened(0.35), a),
		false, 2.5)
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _glint(shape: PackedVector2Array, cx: float, h: float, a: float) -> void:
	var lean:= 14.0
	for band: Vector2 in [Vector2(24.0, 0.08), Vector2(14.0, 0.12), Vector2(6.0, 0.18)]:
		var strip:= PackedVector2Array([
			Vector2(cx - band.x + lean, - h), Vector2(cx + band.x + lean, - h),
			Vector2(cx + band.x - lean, h), Vector2(cx - band.x - lean, h)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(strip, shape):
			_c.draw_colored_polygon(piece, Color(1.0, 1.0, 0.95, band.y * a))


func _fill(pts: PackedVector2Array, col: Color) -> void:
	_c.draw_colored_polygon(pts, col)
	var ring:= pts.duplicate()
	ring.append(pts [0])
	_c.draw_polyline(ring, col, 1.0, true)


static func _rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y)])


static func _a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * alpha)


func _draw_reveal(s: float) -> void:
	var age:= _t - T_REVEAL
	var mid:= _centre() + _jolt(s)
	var fl:= clampf(1.0 - age / 0.24, 0.0, 1.0)
	if fl > 0.0:
		_c.draw_rect(_card_rect(mid, s), Color(1.0, 1.0, 1.0, 0.8 * fl * fl))
		_c.draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.98, 0.9, 0.22 * fl * fl))
	var at:= _icon_at
	var k:= clampf(age / 0.38, 0.0, 1.0)
	if k < 1.0:
		var reach:= lerpf(70.0, 330.0, 1.0 - pow(1.0 - k, 3.0)) * s
		var w:= lerpf(16.0, 1.0, k) * s
		var white:= Color(1.0, 1.0, 1.0, 1.0 - k)

		for blade: Vector2 in [Vector2(0.62, 1.0), Vector2(2.52, 1.0), Vector2(3.77, 1.0),
				Vector2(5.67, 1.0), Vector2(1.57, 0.55), Vector2(4.71, 0.55)]:
			var d:= Vector2.from_angle(blade.x)
			var n:= d.orthogonal()
			_c.draw_colored_polygon(PackedVector2Array([at + n * w, at + d * reach * blade.y,
				at - n * w, at - d * w * 1.5]), white)
		_c.draw_circle(at, 70.0 * s * (1.0 - k), Color(1.0, 1.0, 1.0, 0.9 * (1.0 - k)))
	var rk:= clampf(age / 0.45, 0.0, 1.0)
	if rk < 1.0:
		var rad:= lerpf(60.0, 250.0, 1.0 - pow(1.0 - rk, 3.0)) * s
		_c.draw_arc(at, rad, 0.0, TAU, 72, Color(1.0, 1.0, 1.0, 0.85 * (1.0 - rk)),
			lerpf(12.0, 2.0, rk) * s, true)
	var sk:= clampf(age / 0.42, 0.0, 1.0)
	if sk < 1.0:
		var m:= _mouth(s)
		var grow:= 1.0 - pow(1.0 - clampf(age / 0.12, 0.0, 1.0), 2.0)
		var gold:= Color(COL_GOLD, 1.0 - sk)
		for sp: Vector3 in _splash:
			var d:= Vector2.from_angle(sp.x)
			var n:= d.orthogonal()
			var foot:= m + d * 24.0 * s * sk
			_c.draw_colored_polygon(PackedVector2Array([foot + n * sp.z * s * (1.0 - sk),
				foot + d * sp.y * s * grow, foot - n * sp.z * s * (1.0 - sk)]), gold)


func _draw_strike(s: float, fade: float) -> void:
	var k:= clampf((_t - T_STRIKE) / 0.22, 0.0, 1.0)
	if k <= 0.0 or _price.modulate.a <= 0.0:
		return
	var font:= _price.get_theme_font("font")
	var fs:= _price.get_theme_font_size("font_size")
	var text_w:= font.get_string_size(_price.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * _price.scale.x


	var cy:= _price.position.y + (font.get_ascent(fs) - fs * 0.36) * _price.scale.y
	var x0:= size.x * 0.5 - text_w * 0.5 - 8.0 * s
	var x1:= x0 + (text_w + 16.0 * s) * k
	_c.draw_line(Vector2(x0, cy + 4.0 * s), Vector2(x1, cy - 4.0 * s),
		Color(COL_STRIKE.r, COL_STRIKE.g, COL_STRIKE.b, fade), maxf(5.0 * s, 2.0), true)
