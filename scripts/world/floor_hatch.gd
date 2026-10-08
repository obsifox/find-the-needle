class_name FloorHatch
extends Node3D


const MODEL:= "res://assets/models/floor_hatch.glb"
const SPEC:= "res://assets/models/floor_hatch_materials.json"


const RIM_R:= 0.7
const RIM_TOP:= 0.008
const LID_R:= 0.581
const LID_TOP:= 0.018


const KEEPOUT_FROM:= 0.03
const KEEPOUT_TO:= 2.4


const REACH:= 3.2


const YAW:= PI * 0.5


const INTERIOR:= "Hatch_Interior"

var _model: Node3D
var _anim: AnimationPlayer
var _lid_body: StaticBody3D
var _keepout: StaticBody3D


var unlocked:= false


func _ready() -> void:
	position = Cfg.PILE_CENTER
	rotation.y = YAW
	_build_model()
	_build_lid_body()
	_build_keepout()


func is_locked() -> bool:
	if Cfg.DEMO:
		return true
	return not unlocked


func keepout_body() -> StaticBody3D:
	return _keepout


func lid_body() -> StaticBody3D:
	return _lid_body


func is_hovered(eye: Vector3, look: Vector3) -> bool:
	if _lid_body == null or not is_inside_tree():
		return false
	if eye.distance_to(global_position) > REACH + RIM_R:
		return false
	var q:= PhysicsRayQueryParameters3D.create(eye, eye + look.normalized() * REACH)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PROP
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit ["collider"] == _lid_body


func rattle() -> void:
	if _anim != null and _anim.has_animation("Rattle"):
		_anim.stop()
		_anim.play("Rattle")
	Audio.play_3d("rake_clack", global_position + Vector3.UP * 0.05, -4.0)


func _build_model() -> void:
	var packed:= load(MODEL) as PackedScene
	if packed == null:
		push_warning("FloorHatch: no model at %s" % MODEL)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var inside:= _model.find_child(INTERIOR, true, false) as Node3D
	if inside != null:
		inside.visible = false
	_skin()


func _skin() -> void:
	var spec:= _spec_table()
	if spec.is_empty():
		push_warning("FloorHatch: no material table at %s, the hatch will render untextured" % SPEC)
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi:= node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null or spec.is_empty():
			continue
		for i in mi.mesh.get_surface_count():
			var src:= mi.get_active_material(i)
			if src == null:
				continue
			var key:= src.resource_name
			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = HayCompressor.shared_material(MODEL, key,
					func() -> Material: return HayCompressor.make_material(key, spec, shader))
			if built [key] == null:
				missed [key] = true
				continue
			mi.set_surface_override_material(i, built [key])
	if not missed.is_empty():
		push_warning("FloorHatch: no table entry for %s" % ", ".join(missed.keys()))


static var _spec_cache: Dictionary = { }


static func _spec_table() -> Dictionary:
	if not _spec_cache.is_empty():
		return _spec_cache
	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		_spec_cache = res.data
	elif FileAccess.file_exists(SPEC):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
		if typeof(parsed) == TYPE_DICTIONARY:
			_spec_cache = parsed
	return _spec_cache


func _build_lid_body() -> void:
	var pts:= PackedVector3Array()
	var rings:= [
		Vector2(RIM_R, -0.02),
		Vector2(RIM_R, 0.0),
		Vector2(RIM_R - 0.03, RIM_TOP),
		Vector2(LID_R, LID_TOP),
	]
	const SIDES:= 32
	for ring: Vector2 in rings:
		for k in SIDES:
			var a:= TAU * float(k) / float(SIDES)
			pts.append(Vector3(cos(a) * ring.x, ring.y, sin(a) * ring.x))
	var shape:= ConvexPolygonShape3D.new()
	shape.points = pts
	_lid_body = StaticBody3D.new()
	_lid_body.name = "LidBody"
	_lid_body.collision_layer = Cfg.L_WORLD
	_lid_body.collision_mask = 0
	var col:= CollisionShape3D.new()
	col.shape = shape
	_lid_body.add_child(col)
	add_child(_lid_body)


func _build_keepout() -> void:
	var shape:= CylinderShape3D.new()
	shape.radius = RIM_R
	shape.height = KEEPOUT_TO - KEEPOUT_FROM
	_keepout = StaticBody3D.new()
	_keepout.name = "Keepout"
	_keepout.collision_layer = Cfg.L_KEEPOUT
	_keepout.collision_mask = 0
	var col:= CollisionShape3D.new()
	col.shape = shape
	col.position.y = KEEPOUT_FROM + shape.height * 0.5
	_keepout.add_child(col)
	add_child(_keepout)
