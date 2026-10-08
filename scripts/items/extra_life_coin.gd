class_name ExtraLifeCoin
extends Carryable


const MODEL:= "res://assets/models/extra_life_coin.glb"
const FAR_MODEL:= "res://assets/models/extra_life_coin_particle.glb"
const MESH_NODE:= "ExtraLifeCoin"


const SCALE:= 60.0 / 32.0


const NEAR_RANGE:= 2.5
const NEAR_MARGIN:= 0.25


const PICK_RADIUS:= 0.042
const PICK_HEIGHT:= 0.012
const MASS:= 0.03
const MASK:= Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD

const REST_LIFE:= 2.0
const SHRINK:= 0.3

const REST_SPEED:= 0.08


const MAX_LOOSE:= 12.0

const LOST_Y:= -20.0


const HOLD_OFFSET:= Vector3(-0.04, 0.28, 0.38)


const EAT_HOLD:= 0.7
const EAT_BLINK:= 0.3
const EAT_SHINE:= 0.35
const EAT_SHRINK:= 0.35

const SHAKE_TILT:= 0.3
const SHAKE_SHIFT:= 0.004

const RAYS_SIZE:= 0.26
const RAYS_BACK:= 0.03
const SHINE_SHADER:= preload("res://assets/coin_shine.gdshader")
const RAYS_SHADER:= preload("res://assets/coin_rays.gdshader")

static var _near_mesh: Mesh = null
static var _far_mesh: Mesh = null
static var _looked:= false
static var _bounce: PhysicsMaterial = null


static var _shine_mat: ShaderMaterial = null
static var _rays_mat: ShaderMaterial = null
static var _rays_mesh: QuadMesh = null

var _active:= false

var _gone:= false
var _life:= REST_LIFE
var _loose:= 0.0

var _shrink:= -1.0

var launched_at:= 0

var _eat:= -1.0

var _rays: MeshInstance3D = null

var _charge_voice: AudioStreamPlayer = null


func _init() -> void:
	item_id = "extra_life_coin"
	display_name = Cfg.tr("Extra Life Coin")


func _ready() -> void:
	super ()
	collision_layer = Cfg.L_COIN
	collision_mask = MASK
	mass = MASS


	continuous_cd = true
	angular_damp = 1.5
	if _bounce == null:
		_bounce = PhysicsMaterial.new()
		_bounce.bounce = 0.35
		_bounce.friction = 0.6
	physics_material_override = _bounce


func _build_model() -> void:
	_look_up()
	var root:= Node3D.new()
	root.name = "Model"
	add_child(root)
	var near:= _mesh_instance(_near_mesh, root)
	near.visibility_range_end = NEAR_RANGE
	near.visibility_range_end_margin = NEAR_MARGIN
	var far:= _mesh_instance(_far_mesh, root)
	far.visibility_range_begin = NEAR_RANGE
	far.visibility_range_begin_margin = NEAR_MARGIN


	if _near_mesh != null and _far_mesh != null and _near_mesh.get_surface_count() > 0:
		far.set_surface_override_material(0, _near_mesh.surface_get_material(0))


	_model = root
	_meshes.assign([near, far])


func _mesh_instance(mesh: Mesh, parent: Node3D) -> MeshInstance3D:
	var mi:= MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	var half:= 0.0
	if mesh != null:
		half = mesh.get_aabb().size.z * 0.5 * SCALE
	mi.transform = Transform3D(Basis(Vector3.RIGHT, - PI * 0.5).scaled(Vector3.ONE * SCALE),
		Vector3(0.0, half, 0.0))
	parent.add_child(mi)
	return mi


func _build_shapes() -> void:
	_shape_cylinder(PICK_RADIUS, PICK_HEIGHT, Vector3(0.0, PICK_HEIGHT * 0.5, 0.0))


func carry_pitches() -> bool:
	return true


func carry_aim() -> Basis:
	return Basis(Vector3.RIGHT, PI * 0.5)


func carry_pivot() -> Vector3:
	return - (carry_aim().inverse() * HOLD_OFFSET)


func release(velocity: Vector3, angular: Vector3 = Vector3.ZERO) -> void:

	cancel_eat()
	super (velocity, angular)

	_life = REST_LIFE
	_loose = 0.0


func eat(by: Player) -> void:
	if by != null:
		by.stamina.extra_life()
	cancel_eat()

	if by != null:
		Audio.play("coin_eaten", -12.0)
	_gone = true
	visible = false
	collision_layer = 0
	collision_mask = 0


static func eat_seconds() -> float:
	return EAT_HOLD + EAT_BLINK + EAT_SHINE + EAT_SHRINK


func is_eating() -> bool:
	return _eat >= 0.0


func eat_committed() -> bool:
	return _eat >= EAT_HOLD


func begin_eat() -> void:
	if _eat >= 0.0:
		return
	_eat = 0.0
	_eat_materials()
	for mi in _meshes:
		mi.material_overlay = _shine_mat
	_charge_voice = Audio.play_held("coin_charge", -6.0)


func cancel_eat() -> void:
	if _eat < 0.0:
		return
	_eat = -1.0


	Audio.stop_held(_charge_voice, "coin_charge")
	_charge_voice = null
	set_ride_scale(1.0)
	if _model != null and is_instance_valid(_model):
		_model.visible = true
	var overlay:= hover_material() if _highlighted else null
	for mi in _meshes:
		mi.material_overlay = overlay
	if _rays != null:
		_rays.visible = false


func tick_eat(delta: float, eye: Vector3) -> bool:
	if _eat < 0.0:
		return false
	_eat += delta
	if _eat >= eat_seconds():
		return true
	_draw_eat(eye)
	return false


func _draw_eat(eye: Vector3) -> void:
	if _model == null or not is_instance_valid(_model):
		return
	var t:= _eat
	var shake:= 0.0
	var flash:= 0.0
	var sweep:= -3.0
	var rays:= 0.0
	var size:= 1.0
	var shown:= true
	if t < EAT_HOLD:

		var k:= t / EAT_HOLD
		shake = k * k
		flash = 0.25 * k
	elif t < EAT_HOLD + EAT_BLINK:
		var k:= (t - EAT_HOLD) / EAT_BLINK
		shake = 1.0

		flash = 1.2 if fmod(k * 3.0, 1.0) < 0.5 else 0.2
		rays = 1.0 - pow(1.0 - k, 3.0)
	elif t < EAT_HOLD + EAT_BLINK + EAT_SHINE:
		var k:= (t - EAT_HOLD - EAT_BLINK) / EAT_SHINE
		shake = 1.0 - k
		flash = 0.45
		sweep = lerpf(-1.4, 1.4, k)
		rays = 1.0
	else:
		var k:= minf((t - EAT_HOLD - EAT_BLINK - EAT_SHINE) / EAT_SHRINK, 1.0)
		flash = 0.45 + 0.8 * k
		size = 1.0 - k * k
		rays = 1.0 - k

		shown = k < 0.4 or fmod(k * EAT_SHRINK, 0.06) < 0.035

	var s:= size_scale() * size
	var a:= SHAKE_TILT * shake
	var tilt:= Basis.from_euler(Vector3(sin(t * 47.0) * a, 0.0, sin(t * 59.0 + 1.3) * a))
	var shift:= Vector3(sin(t * 53.0 + 0.4), 0.0, sin(t * 61.0 + 2.1)) * SHAKE_SHIFT * shake
	_model.transform = Transform3D(tilt * _mounted.basis * s, tilt * (_mounted.origin * s) + shift)
	_model.visible = shown
	_shine_mat.set_shader_parameter("flash", flash)
	_shine_mat.set_shader_parameter("sweep", sweep)

	if rays <= 0.0 or not shown:
		if _rays != null:
			_rays.visible = false
		return
	if _rays == null:
		_rays = MeshInstance3D.new()
		_rays.name = "EatRays"
		_rays.mesh = _rays_mesh
		_rays.material_override = _rays_mat
		_rays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		_rays.top_level = true
		add_child(_rays)
	_rays.visible = true
	var centre:= global_position
	var away:= (centre - eye).normalized()
	_rays.global_transform = Transform3D(Basis().scaled(Vector3.ONE * RAYS_SIZE * (0.4 + 0.6 * rays)),
		centre + away * RAYS_BACK)
	_rays_mat.set_shader_parameter("strength", rays)
	_rays_mat.set_shader_parameter("spin", t * 2.0)


static func _eat_materials() -> void:
	if _shine_mat != null:
		return
	_shine_mat = ShaderMaterial.new()
	_shine_mat.shader = SHINE_SHADER
	if _near_mesh != null:
		var box:= _near_mesh.get_aabb()
		_shine_mat.set_shader_parameter("centre", box.get_center())
		_shine_mat.set_shader_parameter("radius", maxf(box.size.x, box.size.y) * 0.5)
	_rays_mat = ShaderMaterial.new()
	_rays_mat.shader = RAYS_SHADER
	_rays_mesh = QuadMesh.new()
	_rays_mesh.size = Vector2.ONE


func is_active() -> bool:
	return _active


func launch(at: Transform3D, velocity: Vector3, spin: Vector3) -> void:
	_active = true
	_gone = false
	_life = REST_LIFE
	_loose = 0.0
	_shrink = -1.0
	launched_at = Time.get_ticks_msec()
	set_ride_scale(1.0)
	visible = true


	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, at)
	global_transform = at
	collision_layer = Cfg.L_COIN
	collision_mask = MASK
	freeze = false
	linear_velocity = velocity
	angular_velocity = spin
	sleeping = false


func park(at: Vector3) -> void:
	cancel_eat()
	_active = false
	_gone = false
	_held = false
	carrier = null
	_shrink = -1.0
	set_ride_scale(1.0)
	visible = false
	collision_layer = 0
	collision_mask = 0
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	var xf:= Transform3D(Basis.IDENTITY, at)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	global_transform = xf


func tick(delta: float) -> bool:
	if _gone:
		return false
	if _held:

		if _shrink >= 0.0:
			_shrink = -1.0
			set_ride_scale(1.0)
		return true
	if global_position.y < LOST_Y:
		return false
	if _shrink >= 0.0:
		_shrink += delta
		set_ride_scale(maxf(0.0, 1.0 - _shrink / SHRINK))
		return _shrink < SHRINK
	_loose += delta
	if sleeping or linear_velocity.length() < REST_SPEED:
		_life -= delta
	if _life <= 0.0 or _loose >= MAX_LOOSE:
		_shrink = 0.0
	return true


static func _look_up() -> void:
	if _looked:
		return
	_looked = true
	_near_mesh = _mesh_from(MODEL)
	_far_mesh = _mesh_from(FAR_MODEL)


static func _mesh_from(path: String) -> Mesh:
	var packed:= load(path) as PackedScene
	if packed == null:
		push_error("ExtraLifeCoin: cannot load %s" % path)
		return null
	var scene:= packed.instantiate()
	var node:= scene.find_child(MESH_NODE, true, false) as MeshInstance3D
	if node == null and scene is MeshInstance3D:
		node = scene as MeshInstance3D
	var mesh: Mesh = node.mesh if node != null else null

	scene.free()
	if mesh == null:
		push_error("ExtraLifeCoin: %s has no %s" % [path, MESH_NODE])
	return mesh
