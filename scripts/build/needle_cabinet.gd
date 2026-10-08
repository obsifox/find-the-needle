class_name NeedleCabinet
extends Node3D


const MODEL:= "res://assets/models/needle_cabinet.glb"
const SPEC:= "res://assets/models/needle_cabinet_materials.json"
const SHADER:= "res://assets/stand_surface.gdshader"


const FLAT_SHADER:= "res://assets/clipped_flat.gdshader"
const TEX:= "res://assets/downloaded/textures/%s/%s_%s_1k.jpg"


const TEX_MAPS:= {
	"albedo": "diff", "normal": "nor_gl", "rough": "rough", "ao": "ao",
}


const ANIM_DOORS:= "DoorsOpen"
const N_READ:= "Marker_Read"


const N_ENDPANEL:= "Cab_EndPanel"
const N_ENDBUTTON:= "End_Button"


const END_LIFT:= 0.91
const END_FALL:= 1.05


const END_SHRINK:= 0.4


const END_RISE_RATE:= 0.85
const END_SKEW_RATE:= 0.12

const END_BEAT:= 0.35


const END_CHIME_AT:= 0.55
const END_CHIME_DB:= -4.0


const END_PRESSES:= 3
const END_NUM_SIZE:= 150
const END_NUM_PIXEL:= 0.00042


const END_NUM_DROP:= 0.135


const END_SINK:= 0.01


const END_RETRACT:= 0.074
const END_RETRACT_TIME:= 0.14


const END_SLAM_SPEED:= 3.4


const LCD_SEGMENTS:= 7
const LCD_DIGITS:= [
	63,
	6,
	91,
	79,
	102,
	109,
	125,
	7,
	127,
	111,
]


const LCD_GHOST:= 0.085


const END_GLOW_SCALE:= 1.06


const REVEAL_FLASH:= 2.2
const REVEAL_GAIN:= 4.5


const SPARK_SIZE:= 0.06


const DRAWER_SLIDE:= 0.15
const DRAWER_OUT_TIME:= 0.16
const DRAWER_HOLD:= 0.85
const DRAWER_IN_TIME:= 0.45


const COUNT_SIZE:= 44
const COUNT_PIXEL:= 0.0004
const COL_COUNT:= Color(0.86, 0.72, 0.34)


const MARKER_ALPHA:= 0.8
const MARKER_GLOW:= 3.2

const MARKER_MIN_LUMA:= 0.52


const MARKER_PULSE:= 1.3

signal deposited(type: int, fresh: bool)


signal ending_pressed

var placement_preview:= false

var _model: Node3D
var _doors: AnimationPlayer
var _slots: Dictionary = { }


var end_chimes:= 0
var _slot_mats: Dictionary = { }
var _read_at:= Vector3.ZERO
var _sparks: GPUParticles3D
var _flash:= 0.0
var _flash_type:= -1
var _open:= false
var _preview_ok:= true
var _preview_mats: Array [StandardMaterial3D] = []


var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var _marker_type:= -1


var _marker_t:= 0.0


var _marker_tint:= Color.WHITE
var _drawers: Array [Node3D] = []
var _drawer_home: Array [Vector3] = []


var _drawer_t: PackedFloat32Array = PackedFloat32Array()


var _front:= 1.0
var _counts: Dictionary = { }


var _endpanel: Node3D
var _end_button: Node3D
var _end_home:= Vector3.ZERO


var _ending:= false
var _end_armed:= false

var _end_glow: MeshInstance3D


var _end_mats: Array [ShaderMaterial] = []


var _end_pending:= false


var _end_left:= 0
var _lcd_segs: Array [ShaderMaterial] = []
var _lcd_on:= Vector3.ONE
var _lcd_emit:= 0.0


var _end_button_home:= Vector3.ZERO


var _end_move: Tween


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


var gift:= false


func build_cost() -> float:
	return 0.0 if gift else Cfg.CABINET_COST


func to_dict() -> Dictionary:
	return {
		"type": "needle_cabinet",
		"position": position,
		"yaw": rotation.y,
		"gift": gift,
	}


func _ready() -> void:
	_build_model()
	_skin()
	_bind_doors()
	_collect_slots()
	if placement_preview:
		set_process(false)
		set_physics_process(false)
		set_preview_valid(true)
		return


	FactoryClock.join(self)
	_collect_drawers()
	_collect_endpanel()
	_build_counts()
	_build_sparks()
	add_to_group("needle_cabinets")


	_sync_case()
	_sync_counts()
	GameState.needle_stock_changed.connect(_on_stock_changed)


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("NeedleCabinet: cannot load %s" % MODEL)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)


	for n in _model.find_children("*", "StaticBody3D", true, false):
		var body:= n as StaticBody3D
		body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
		body.collision_mask = 0
	if not placement_preview:
		_catch_box = _measure_case()

	var marker:= _model.find_child(N_READ, true, false) as Node3D
	if marker != null:
		_read_at = marker.position
	if placement_preview:
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if _model == null:
		return out
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func _skin() -> void:
	if _model == null:
		return
	var spec:= _load_spec()
	if spec.is_empty():
		push_warning("NeedleCabinet: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	for mesh in _meshes():
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null:
				continue
			var key:= src.resource_name

			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = _make_surface(key, spec, shader)
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
	if not missed.is_empty():
		push_warning("NeedleCabinet: no table entry for %s" % ", ".join(missed.keys()))


func _load_spec() -> Dictionary:
	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		return res.data
	if not FileAccess.file_exists(SPEC):
		return { }
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else { }


func _make_surface(key: String, spec: Dictionary, shader: Shader) -> Material:
	var surfaces: Dictionary = spec.get("surfaces", { })
	if surfaces.has(key):
		var d: Dictionary = surfaces [key]
		var asset: String = d ["asset"]
		var m:= ShaderMaterial.new()
		m.shader = shader
		m.resource_name = key
		for slot: String in TEX_MAPS:
			var path: String = TEX % [asset, asset, TEX_MAPS [slot]]
			if ResourceLoader.exists(path):
				m.set_shader_parameter("tex_" + slot, load(path))
		m.set_shader_parameter("per_metre", float(d ["per_metre"]))
		m.set_shader_parameter("tint", _col(d ["tint"]))
		m.set_shader_parameter("saturation", float(d.get("sat", 1.0)))
		var rough: Array = d ["rough"]
		m.set_shader_parameter("rough_min", float(rough [0]))
		m.set_shader_parameter("rough_max", float(rough [1]))
		m.set_shader_parameter("metallic_amount", float(d.get("metal", 0.0)))
		m.set_shader_parameter("normal_strength", float(d.get("nor", 1.0)))
		m.set_shader_parameter("ao_strength", float(d.get("ao", 0.0)))
		return m

	var flats: Dictionary = spec.get("flats", { })
	if flats.has(key):
		var f: Dictionary = flats [key]
		var sm:= StandardMaterial3D.new()
		sm.resource_name = key
		var colour:= _col(f ["color"])
		var alpha:= float(f.get("alpha", 1.0))
		sm.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
		sm.roughness = float(f.get("rough", 0.6))
		sm.metallic = float(f.get("metal", 0.0))
		sm.metallic_specular = 0.4
		var emit:= float(f.get("emit", 0.0))
		if emit > 0.0:
			sm.emission_enabled = true
			sm.emission = colour
			sm.emission_energy_multiplier = emit
		if alpha < 1.0:
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		return sm
	return null


func _col(a: Variant) -> Color:
	var v: Array = a
	return Color(float(v [0]), float(v [1]), float(v [2]))


static var _flats: Dictionary = { }


static func type_colour(type: int) -> Color:
	var f:= flat_spec(NeedleTypes.material_of(type))
	if not f.has("color"):
		return Cfg.COL_NEEDLE
	var c: Array = f ["color"]
	return Color(float(c [0]), float(c [1]), float(c [2]))


static var _surfs: Dictionary = { }


static func flat_spec(key: String) -> Dictionary:
	if _flats.is_empty() and _surfs.is_empty():
		var table: Dictionary = { }
		var res: JSON = load(SPEC) as JSON
		if res != null and typeof(res.data) == TYPE_DICTIONARY:
			table = res.data
		elif FileAccess.file_exists(SPEC):
			var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(SPEC))
			if typeof(parsed) == TYPE_DICTIONARY:
				table = parsed
		_flats = table.get("flats", { })
		_surfs = table.get("surfaces", { })
	if _flats.has(key):
		return _flats [key]
	if _surfs.has(key):
		var s: Dictionary = _surfs [key]
		var r: Array = s.get("rough", [0.6, 0.6])
		return {
			"color": s.get("tint", [1, 1, 1]),
			"rough": (float(r [0]) + float(r [1])) * 0.5,
			"metal": s.get("metal", 0.0),
		}
	return { }


static var _type_meshes: Dictionary = { }
static var _type_meshes_loaded:= false


static func type_mesh(type: int) -> Mesh:
	if not _type_meshes_loaded:
		_type_meshes_loaded = true
		var scn: PackedScene = load(MODEL) as PackedScene
		if scn == null:
			push_warning("NeedleCabinet: cannot load %s for specimen meshes" % MODEL)
		else:
			var root: Node = scn.instantiate()
			for t in NeedleTypes.count():
				var mi:= root.find_child(NeedleTypes.object_of(t), true, false) as MeshInstance3D
				if mi != null and mi.mesh != null:
					_type_meshes [t] = mi.mesh
			root.queue_free()
	return _type_meshes.get(type, null) as Mesh


func _bind_doors() -> void:
	if _model == null:
		return
	var ap:= _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		push_warning("NeedleCabinet: %s has no AnimationPlayer; the doors will not move" % MODEL)
		return
	_doors = ap


	for lib_name in ap.get_animation_library_list():
		var lib:= ap.get_animation_library(lib_name)
		for clip in lib.get_animation_list():
			lib.get_animation(clip).loop_mode = Animation.LOOP_NONE


func _collect_slots() -> void:
	if _model == null:
		return
	for t in NeedleTypes.count():
		var node:= _model.find_child(NeedleTypes.object_of(t), true, false)
		var mesh:= node as MeshInstance3D
		if mesh == null:
			push_warning("NeedleCabinet: %s missing from the model" % NeedleTypes.object_of(t))
			continue
		_slots [t] = mesh


		mesh.visible = placement_preview


func _collect_drawers() -> void:
	if _model == null:
		return
	_front = 1.0 if _read_at.z >= 0.0 else -1.0
	var i:= 0
	while true:
		var node:= _model.find_child("Drawer_%d" % i, true, false) as Node3D
		if node == null:
			break
		_drawers.append(node)
		_drawer_home.append(node.position)
		_drawer_t.append(-1.0)
		i += 1


func _drawer_of(type: int) -> int:
	if _drawers.is_empty():
		return -1
	var per:= int(ceil(float(NeedleTypes.count()) / float(_drawers.size())))
	return clampi(type / maxi(per, 1), 0, _drawers.size() - 1)


func _build_counts() -> void:
	if _model == null or _slots.is_empty():
		return
	var pitch:= _cell_pitch()
	for t: int in _slots:
		var mesh:= _slots [t] as MeshInstance3D
		var label:= Label3D.new()
		label.name = "Count_%02d" % t
		label.font = UiFont.bold()
		label.font_size = COUNT_SIZE
		label.pixel_size = COUNT_PIXEL
		label.modulate = COL_COUNT
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.shaded = false
		label.double_sided = false
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM


		var at:= to_local(mesh.global_position)
		at.x += pitch.x * 0.3
		at.y -= pitch.y * 0.34
		at.z += _front * 0.035
		label.position = at
		if _front < 0.0:
			label.rotation.y = PI
		label.visible = false
		add_child(label)
		_counts [t] = label


func _cell_pitch() -> Vector2:
	var cols:= maxi(NeedleTypes.cols(), 1)
	var pitch:= Vector2(0.208, 0.212)
	if _slots.has(0) and _slots.has(1):
		pitch.x = absf(to_local((_slots [1] as MeshInstance3D).global_position).x
			- to_local((_slots [0] as MeshInstance3D).global_position).x)
	if _slots.has(0) and _slots.has(cols):
		pitch.y = absf(to_local((_slots [cols] as MeshInstance3D).global_position).y
			- to_local((_slots [0] as MeshInstance3D).global_position).y)
	return pitch


func _sync_counts() -> void:
	for t: int in _counts:
		_write_count(t)


func _on_stock_changed(type: int, _held: int) -> void:
	_write_count(type)
	if _slots.has(type):
		(_slots [type] as MeshInstance3D).visible = has_specimen(type)


func _write_count(type: int) -> void:
	var label:= _counts.get(type) as Label3D
	if label == null:
		return
	var held:= GameState.stock_of(type)
	label.text = "x%d" % held
	label.visible = held > 0


func _build_sparks() -> void:
	var pm:= ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 55.0


	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.42
	pm.gravity = Vector3(0, -0.55, 0)


	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	var ramp:= Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.62, 1.0))
	ramp.set_color(1, Color(1.0, 0.72, 0.2, 0.0))
	var ramp_tex:= GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex


	var quad:= GlintParticles.draw_quad(SPARK_SIZE)

	_sparks = GPUParticles3D.new()
	_sparks.name = "RevealSparks"


	_sparks.amount = 18
	_sparks.lifetime = 1.0
	_sparks.one_shot = true
	_sparks.explosiveness = 0.95
	_sparks.emitting = false
	_sparks.draw_pass_1 = quad
	_sparks.process_material = pm
	_sparks.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	add_child(_sparks)


func has_specimen(type: int) -> bool:
	return GameState.is_discovered(type) and GameState.stock_of(type) > 0


func _sync_case() -> void:
	for t: int in _slots:
		(_slots [t] as MeshInstance3D).visible = has_specimen(t)


func slot_position(type: int) -> Vector3:
	if _slots.has(type):
		return (_slots [type] as MeshInstance3D).global_position
	return global_position + Vector3(0, 1.35, 0)


func read_position() -> Vector3:
	return to_global(_read_at)


const REACH:= 2.1


func in_reach(from: Vector3) -> bool:
	return from.distance_to(read_position()) <= REACH


const LOOK:= 3.2


func prompt() -> String:
	var seen:= 0
	for t in NeedleTypes.count():
		if GameState.is_discovered(t):
			seen += 1
	var verb:= tr("Close the case") if _open else tr("Open the case")
	return tr("%s  (%d/%d found)") % [verb, seen, NeedleTypes.count()]


func interact() -> void:
	if _doors == null:
		return
	if _open:
		close_doors()
	else:
		open_doors()


func is_open() -> bool:
	return _open


func accept(index: int) -> void:
	var type:= GameState.type_of(index)
	var at:= slot_position(type)
	GameState.deposit_needle(index, at)


	var fresh:= GameState.discover(type, at)
	if not fresh:
		_acknowledge(type)
	deposited.emit(type, fresh)


	if fresh and _endpanel != null and GameState.collection_complete():
		_end_pending = true


func _acknowledge(type: int) -> void:
	if _sparks != null:
		_sparks.global_position = slot_position(type)
		_sparks.restart()
		_sparks.emitting = true
	Audio.play_3d("needle_ting", slot_position(type), -3.0)


var live: LiveStrandManager


var _catch_box:= AABB()


func factory_tick(delta: float) -> void:
	if live == null or _ending or live.needles.is_empty() or not _catch_box.has_volume():
		return

	var caught: Array [RigidBody3D] = []
	for b in live.needles:
		if not is_instance_valid(b):
			continue


		if (_at_case(b, DIP_REACH) and _dipped(b)) or (_free_to_catch(b) and _reaches_case(b, delta)):
			caught.append(b)
	for b in caught:
		var index:= int(b.get_meta("needle_index", -1))
		if live.consume_needle(b):
			accept(index)


static func _free_to_catch(b: RigidBody3D) -> bool:


	if int(b.get_meta("needle_index", -1)) < 0:
		return false


	if b.freeze and not LiveStrandManager.is_pinned(b):
		return false


	if b.get_meta(LiveStrandManager.META_PROTECTED, false) and not Shovel.let_go_recently(b):
		return false
	return true


const DIP_REACH:= 0.15


func _dipped(b: RigidBody3D) -> bool:
	if int(b.get_meta("needle_index", -1)) < 0:
		return false
	for n in get_tree().get_nodes_in_group(Shovel.GROUP):
		var blade:= n as Shovel
		if blade != null and blade.carries(b):
			return true
	return false


func _reaches_case(b: RigidBody3D, delta: float) -> bool:
	return _at_case(b, b.linear_velocity.length() * delta)


func _at_case(b: RigidBody3D, extra: float) -> bool:
	var ext:= StrandFactory.needle_extents(int(b.get_meta("needle_type", 0)))
	var reach:= maxf(ext.x, maxf(ext.y, ext.z)) + extra
	return _catch_box.grow(reach).has_point(to_local(b.global_position))


func _measure_case() -> AABB:
	var box:= AABB()
	var first:= true
	var to_me:= global_transform.affine_inverse()
	for n in _model.find_children("*", "CollisionShape3D", true, false):
		var cs:= n as CollisionShape3D
		if cs.shape == null:
			continue
		var part:= (to_me * cs.global_transform) * cs.shape.get_debug_mesh().get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


func show_slot_marker(type: int) -> void:
	if not _slots.has(type):
		hide_slot_marker()
		return
	if _marker == null:
		_build_marker()
	if type != _marker_type:
		_marker_type = type
		var mesh:= _slots [type] as MeshInstance3D
		_marker.mesh = mesh.mesh


		var tint:= type_colour(type)


		var lit:= tint.lerp(Color.WHITE, 0.35)


		var lum:= lit.get_luminance()
		if lum < MARKER_MIN_LUMA:
			lit = lit.lerp(Color.WHITE,
				(MARKER_MIN_LUMA - lum) / maxf(1.0 - lum, 0.001))
		_marker_tint = lit
		_marker_mat.albedo_color = Color(lit.r, lit.g, lit.b, 0.0)
		_marker_mat.emission = lit


		_marker.global_transform = mesh.global_transform
	if not _marker.visible:
		_marker_t = 0.0
		_marker.visible = true


	set_process(true)


func hide_slot_marker() -> void:
	if _marker != null:
		_marker.visible = false
		_marker_t = 0.0


func _build_marker() -> void:
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


	_marker_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marker_mat.emission_enabled = true
	_marker_mat.emission_energy_multiplier = MARKER_GLOW
	_marker_mat.no_depth_test = true


	_marker_mat.render_priority = 2
	_marker = MeshInstance3D.new()
	_marker.name = "SlotMarker"


	_marker.top_level = true
	_marker.material_override = _marker_mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)


func reveal(type: int) -> void:


	if not is_inside_tree() or not _slots.has(type):
		return
	var mesh:= _slots [type] as MeshInstance3D
	mesh.visible = true
	if not _slot_mats.has(type):
		var src:= mesh.get_active_material(0)
		if src is StandardMaterial3D:
			var dup:= (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(0, dup)
			_slot_mats [type] = dup
	_flash_type = type
	_flash = REVEAL_FLASH
	if _end_pending:
		_end_pending = false
		_end_after_reveal()


	open_doors()
	if _sparks != null:
		_sparks.global_position = slot_position(type)
		_sparks.restart()
		_sparks.emitting = true
	Audio.play_3d("needle_ting", slot_position(type), -1.0)
	set_process(true)


func open_doors() -> void:
	if _doors == null or not _doors.has_animation(ANIM_DOORS):
		return


	if _open:
		return
	_open = true
	_doors.play(ANIM_DOORS)
	Audio.play_3d("cabinet_open", read_position(), -6.0)


	if ending_covered():
		_end_left = END_PRESSES
		_show_end_count()
		_extend_button(true)


func close_doors() -> void:
	if _doors == null or not _doors.has_animation(ANIM_DOORS):
		return


	if not _open:
		return
	_open = false
	if ending_covered():


		_extend_button(false)
		_slam_doors()
		return
	Audio.play_3d("cabinet_close", read_position(), -7.0)
	_doors.play_backwards(ANIM_DOORS)


func _slam_doors() -> void:
	_doors.play(ANIM_DOORS, -1.0, - END_SLAM_SPEED, true)
	var swing:= _doors.get_animation(ANIM_DOORS).length / END_SLAM_SPEED
	await get_tree().create_timer(swing).timeout
	Audio.play_3d("build_place_big", read_position(), 0.0)
	Audio.play_3d("cabinet_close", read_position(), -5.0)


func _extend_button(out: bool) -> void:
	if _end_button == null:
		return


	_kill_button_move()
	if not out and _end_glow != null:

		_end_glow.visible = false
	var to:= _end_button_home
	if not out:
		to += Vector3(0, 0, - _front * END_RETRACT)
	_end_move = create_tween()
	_end_move.tween_property(_end_button, "position", to, END_RETRACT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _kill_button_move() -> void:
	if _end_move != null and _end_move.is_valid():
		_end_move.kill()
	_end_move = null


func _collect_endpanel() -> void:
	if _model == null:
		return
	_endpanel = _model.find_child(N_ENDPANEL, true, false) as Node3D
	if _endpanel == null:


		return
	_end_button = _endpanel.find_child(N_ENDBUTTON, true, false) as Node3D
	_end_home = _endpanel.position
	if _end_button != null:
		_end_button_home = _end_button.position
	_endpanel.visible = false
	_own_end_materials()
	_collect_lcd()


func ending_armed() -> bool:
	return _end_armed and _end_button != null and _open and _end_left > 0


func ending_covered() -> bool:
	return _ending


func ending_button_at() -> Vector3:
	if _end_button == null:
		return global_position
	return _end_button.global_position


func _own_end_materials() -> void:
	_end_mats.clear()
	if _endpanel == null:
		return
	var flat_shader: Shader = load(FLAT_SHADER)


	var kids: Array [Node] = [_endpanel]
	kids.append_array(_endpanel.find_children("*", "MeshInstance3D", true, false))
	for node: Node in kids:
		var mesh:= node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_surface_override_material(i)
			var mine: ShaderMaterial = null
			if src is ShaderMaterial:
				mine = (src as ShaderMaterial).duplicate() as ShaderMaterial
			elif src is StandardMaterial3D and flat_shader != null:
				mine = _clipped_flat(src as StandardMaterial3D, flat_shader)
			if mine == null:
				continue
			mesh.set_surface_override_material(i, mine)
			_end_mats.append(mine)


func _clipped_flat(src: StandardMaterial3D, shader: Shader) -> ShaderMaterial:
	var m:= ShaderMaterial.new()
	m.shader = shader
	m.resource_name = src.resource_name
	var c:= src.albedo_color
	m.set_shader_parameter("albedo", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("rough", src.roughness)
	m.set_shader_parameter("metal", src.metallic)
	m.set_shader_parameter("spec", src.metallic_specular)
	if src.emission_enabled:
		m.set_shader_parameter("emit_strength", src.emission_energy_multiplier)
	return m


func _clip_end_above(y: float) -> void:
	for m in _end_mats:
		m.set_shader_parameter("clip_above", y)


func _collect_lcd() -> void:
	_lcd_segs.clear()
	if _endpanel == null:
		return
	for i in LCD_SEGMENTS:
		var seg:= _endpanel.find_child("Lcd_S%d" % i, true, false) as MeshInstance3D
		if seg == null:
			continue
		var m:= seg.get_surface_override_material(0) as ShaderMaterial
		if m != null:
			_lcd_segs.append(m)
	if _lcd_segs.size() == LCD_SEGMENTS:


		_lcd_on = _lcd_segs [0].get_shader_parameter("albedo")
		_lcd_emit = float(_lcd_segs [0].get_shader_parameter("emit_strength"))


func _show_end_count() -> void:
	if _lcd_segs.size() < LCD_SEGMENTS:
		return
	var mask: int = LCD_DIGITS [clampi(_end_left, 0, LCD_DIGITS.size() - 1)]
	for i in LCD_SEGMENTS:
		var lit:= ((mask >> i) & 1) == 1
		var m:= _lcd_segs [i]
		m.set_shader_parameter("albedo", _lcd_on if lit else _lcd_on * LCD_GHOST)
		m.set_shader_parameter("emit_strength", _lcd_emit if lit else 0.0)


func press_ending() -> bool:
	if not ending_armed():
		return false
	var home:= _end_button_home
	_kill_button_move()
	_end_move = create_tween()
	_end_move.tween_property(_end_button, "position",
		home + Vector3(0, 0, - _front * END_SINK), 0.07)
	_end_left -= 1
	_show_end_count()
	if _end_left <= 0:


		close_doors()
	else:
		_end_move.tween_property(_end_button, "position", home, 0.16)
	Audio.play_3d("ui_click", ending_button_at(), -1.0)
	ending_pressed.emit()
	return true


func highlight_ending(on: bool) -> void:
	if _end_button == null:
		return
	if _end_glow == null:
		if not on:
			return
		var src:= _end_button as MeshInstance3D
		if src == null or src.mesh == null:
			return
		_end_glow = MeshInstance3D.new()
		_end_glow.name = "EndGlow"
		_end_glow.mesh = src.mesh
		_end_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_end_glow.material_override = AimHighlight._outline_material()


		_end_glow.scale = Vector3.ONE * END_GLOW_SCALE
		src.add_child(_end_glow)
	_end_glow.visible = on


const END_LAST_LOOK:= 1.6


func _end_after_reveal() -> void:
	await get_tree().create_timer(END_LAST_LOOK).timeout
	play_ending()


func play_ending() -> void:
	if _ending or _endpanel == null:
		return
	_ending = true


	if not _open:
		open_doors()
		if _doors != null and _doors.has_animation(ANIM_DOORS):
			await get_tree().create_timer(
				_doors.get_animation(ANIM_DOORS).length).timeout
	await _shrink_specimens()
	await get_tree().create_timer(END_BEAT).timeout
	await _drop_panel()
	_end_armed = true
	_end_left = END_PRESSES
	_show_end_count()


func _shrink_specimens() -> void:
	end_chimes = 0
	var live: Array [MeshInstance3D] = []
	for t: int in _slots:
		var mesh:= _slots [t] as MeshInstance3D
		if mesh != null and mesh.visible:
			live.append(mesh)
	if live.is_empty():
		return


	var low:= INF
	var left:= INF
	for mesh in live:
		var lp:= _model.to_local(mesh.global_position)
		low = minf(low, lp.y)
		left = minf(left, lp.x)


	var rows: Dictionary = { }
	var last:= 0.0
	for mesh in live:
		var lp:= _model.to_local(mesh.global_position)
		var rise:= (lp.y - low) * END_RISE_RATE
		var delay:= rise + (lp.x - left) * END_SKEW_RATE
		last = maxf(last, delay)
		var band:= snappedf(lp.y - low, 0.02)
		if not rows.has(band):
			rows [band] = [rise, mesh.global_position]
		var tw:= create_tween()
		tw.tween_interval(delay)


		tw.tween_property(mesh, "scale", Vector3.ZERO, END_SHRINK).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: mesh.visible = false)
	for band: float in rows:
		var row: Array = rows [band]
		end_chimes += 1
		Audio.play_3d_delayed("needle_collect", row [1] as Vector3,
			(row [0] as float) + END_SHRINK * END_CHIME_AT, END_CHIME_DB)
	await get_tree().create_timer(last + END_SHRINK).timeout


func _drop_panel() -> void:
	if _endpanel == null:
		return
	_endpanel.position = _end_home + Vector3(0, END_LIFT, 0)


	var top:= _model.to_global(_end_home).y
	var box:= _endpanel as MeshInstance3D
	if box != null:
		top += box.get_aabb().size.y * 0.5
	_clip_end_above(top)
	_endpanel.visible = true
	var tw:= create_tween()


	tw.tween_property(_endpanel, "position", _end_home, END_FALL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished


	_clip_end_above(INF)


	Audio.play_3d("build_place_big", read_position(), 0.0)


func slot_at(point: Vector3, dir: Vector3 = Vector3.ZERO) -> int:
	if _slots.is_empty():
		return -1
	var here:= to_local(point)


	var plane_z:= to_local((_slots [_slots.keys() [0]] as MeshInstance3D).global_position).z
	if dir != Vector3.ZERO:
		var along:= (global_transform.basis.inverse() * dir).normalized()
		if absf(along.z) > 0.01:
			var t:= (plane_z - here.z) / along.z


			if t > 0.0:
				here += along * t
	var best:= -1
	var best_d:= INF
	for t: int in _slots:
		var at:= to_local((_slots [t] as MeshInstance3D).global_position)


		var d:= Vector2(at.x - here.x, at.y - here.y).length_squared()
		if d < best_d:
			best_d = d
			best = t
	return best


func can_take(type: int) -> bool:
	return not placement_preview and _open and GameState.stock_of(type) > 0


func withdraw(type: int) -> int:
	if not can_take(type):
		return -1
	var index:= GameState.withdraw_needle(type, slot_position(type))
	if index < 0:
		return -1
	slide_drawer(type)
	Audio.play_3d("needle_ting", slot_position(type), -5.0)
	return index


func slide_drawer(type: int) -> void:
	var i:= _drawer_of(type)
	if i < 0:
		return
	_drawer_t [i] = 0.0
	Audio.play_3d("cabinet_open", read_position(), -9.0)
	set_process(true)


func _drawer_offset(i: int) -> float:
	var t:= _drawer_t [i]
	if t < 0.0:
		return 0.0
	if t < DRAWER_OUT_TIME:

		return DRAWER_SLIDE * smoothstep(0.0, 1.0, t / DRAWER_OUT_TIME)
	if t < DRAWER_OUT_TIME + DRAWER_HOLD:
		return DRAWER_SLIDE
	var k:= (t - DRAWER_OUT_TIME - DRAWER_HOLD) / DRAWER_IN_TIME
	return DRAWER_SLIDE * (1.0 - smoothstep(0.0, 1.0, k))


func _step_drawers(delta: float) -> bool:
	var busy:= false
	for i in _drawers.size():
		if _drawer_t [i] < 0.0:
			continue
		_drawer_t [i] += delta
		var home: Vector3 = _drawer_home [i]
		_drawers [i].position = home + Vector3(0, 0, _front * _drawer_offset(i))
		if _drawer_t [i] >= DRAWER_OUT_TIME + DRAWER_HOLD + DRAWER_IN_TIME:
			_drawer_t [i] = -1.0
			_drawers [i].position = home
			Audio.play_3d("cabinet_close", read_position(), -10.0)
		else:
			busy = true
	return busy


func marker_pulse() -> float:
	if _marker == null or not _marker.visible:
		return 0.0
	return 0.5 - 0.5 * cos(_marker_t / MARKER_PULSE * TAU)


func _pulse_marker(delta: float) -> bool:
	if _marker == null or not _marker.visible or _marker_mat == null:
		return false
	_marker_t = fmod(_marker_t + delta, MARKER_PULSE)


	var k:= 0.5 - 0.5 * cos(_marker_t / MARKER_PULSE * TAU)
	_marker_mat.albedo_color = Color(_marker_tint.r, _marker_tint.g,
		_marker_tint.b, MARKER_ALPHA * k)


	_marker_mat.emission_energy_multiplier = MARKER_GLOW * k
	return true


func _process(delta: float) -> void:
	var drawers_busy:= _step_drawers(delta)
	var ghost_up:= _pulse_marker(delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		var mat: StandardMaterial3D = _slot_mats.get(_flash_type)
		if mat != null:
			var k:= _flash / REVEAL_FLASH

			var gain:= REVEAL_GAIN * k * k
			mat.emission_enabled = gain > 0.001
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = gain
	if _flash <= 0.0 and not drawers_busy and not ghost_up:
		set_process(false)


func set_preview_valid(ok: bool) -> void:
	if not placement_preview:
		return
	if _preview_ok == ok and not _preview_mats.is_empty():
		return
	_preview_ok = ok
	var col:= Cfg.COL_GHOST_OK if ok else Cfg.COL_GHOST_BAD
	if _preview_mats.is_empty():
		for mesh in _meshes():
			if mesh.mesh == null:
				continue
			for i in mesh.mesh.get_surface_count():
				var m:= StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_color = Color(col.r, col.g, col.b, 0.38)
				mesh.set_surface_override_material(i, m)
				_preview_mats.append(m)
	else:
		for m in _preview_mats:
			m.albedo_color = Color(col.r, col.g, col.b, 0.38)
