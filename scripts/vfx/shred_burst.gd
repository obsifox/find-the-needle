class_name ShredBurst
extends GPUParticles3D


const MAT_FACE:= "M_PM_Paper"
const MAT_EDGE:= "M_PM_PaperEdge"


const FALLBACK_FACE:= Color(0.73, 0.61, 0.4)
const FALLBACK_EDGE:= Color(0.49, 0.37, 0.205)


const SHRED:= Vector3(0.075, 0.004, 0.026)


const COUNT:= 90
const LIFETIME:= 1.1


const SPEED_MIN:= 0.7
const SPEED_MAX:= 2.4


const GRAVITY:= 2.2

var _left:= 0.0


static func play(at: Vector3, basis: Basis, box: Vector3, parent: Node3D) -> ShredBurst:
	if parent == null or not parent.is_inside_tree():
		return null
	var fx:= ShredBurst.new()
	fx.name = "Shreds"
	fx._build(box)
	parent.add_child(fx)


	fx.global_transform = Transform3D(basis.orthonormalized(),
		at + basis.y.normalized() * box.y * 0.5)
	return fx


func _build(box: Vector3) -> void:
	var pm:= ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX


	pm.emission_box_extents = box * 0.5


	pm.direction = Vector3(0.0, 0.55, 0.0)
	pm.spread = 85.0
	pm.initial_velocity_min = SPEED_MIN
	pm.initial_velocity_max = SPEED_MAX
	pm.gravity = Vector3(0.0, - GRAVITY, 0.0)


	pm.damping_min = 0.9
	pm.damping_max = 2.0
	pm.angular_velocity_min = -640.0
	pm.angular_velocity_max = 640.0
	pm.particle_flag_rotate_y = true
	pm.scale_min = 0.65
	pm.scale_max = 1.35
	pm.lifetime_randomness = 0.32

	var colours:= Gradient.new()
	colours.set_color(0, _paper(MAT_EDGE, FALLBACK_EDGE))
	colours.set_color(1, _paper(MAT_FACE, FALLBACK_FACE))
	var ramp:= GradientTexture1D.new()
	ramp.gradient = colours
	pm.color_initial_ramp = ramp


	var shrink:= Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.66, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	var shrink_tex:= CurveTexture.new()
	shrink_tex.curve = shrink
	pm.scale_curve = shrink_tex

	var mesh:= BoxMesh.new()
	mesh.size = SHRED
	var mat:= StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.88
	mat.metallic = 0.0


	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat

	amount = COUNT
	lifetime = LIFETIME
	one_shot = true

	explosiveness = 1.0


	emitting = false
	local_coords = false
	fixed_fps = 30
	interpolate = true
	fract_delta = true
	process_material = pm
	draw_pass_1 = mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	visibility_aabb = AABB(Vector3(-2.5, -1.5, -2.5), Vector3(5.0, 4.0, 5.0))
	_left = LIFETIME * (1.0 + pm.lifetime_randomness) + 0.1


func _ready() -> void:
	emitting = true


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()


static func _paper(key: String, fallback: Color) -> Color:
	var flats: Dictionary = PaperRoll.spec_table().get("flats", { })
	if not flats.has(key):
		return fallback
	var entry: Dictionary = flats [key]
	var arr: Array = entry.get("color", [])
	if arr.size() < 3:
		return fallback
	return Color(float(arr [0]), float(arr [1]), float(arr [2]))
