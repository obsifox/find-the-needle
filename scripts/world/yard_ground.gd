class_name YardGround
extends Node3D


const GROUND_Y:= -0.11


const PAD_HALF:= 16.0
const PAD_OUT:= 21.0


const ROAD_W:= 6.2
const ROAD_END:= 250.0

const FENCE_H:= 1.18
const POST_GAP:= 3.4


const TRACK_FENCE_HALF:= ROAD_W * 0.5 + 2.6


const CORRIDOR_OUT:= 56.0
const FOG_FROM:= 30.0

const TEX:= "res://assets/downloaded/textures/%s/%s_%s_1k.jpg"

var _mat_pad: StandardMaterial3D
var _mat_track: StandardMaterial3D
var _mat_wood: StandardMaterial3D


var wall_x0:= -17.5
var wall_x1:= 17.5


var shed_depth:= 35.0


func _ready() -> void:
	_build_materials()
	_build_pad()
	_build_fence()


func _pbr(asset: String, scale: float, tint:= Color.WHITE) -> StandardMaterial3D:
	var m:= StandardMaterial3D.new()
	var diff: Texture2D = load(TEX % [asset, asset, "diff"])
	if diff == null:
		push_warning("YardGround: missing texture set '%s', falling back to flat" % asset)
		m.albedo_color = tint
		return m
	m.albedo_texture = diff
	m.albedo_color = tint
	var nrm: Texture2D = load(TEX % [asset, asset, "nor_gl"])
	if nrm != null:
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = 1.0
	var rgh: Texture2D = load(TEX % [asset, asset, "rough"])
	if rgh != null:
		m.roughness_texture = rgh
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic = 0.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.uv1_triplanar_sharpness = 8.0
	return m


func _build_materials() -> void:


	_mat_pad = _pbr("concrete_floor_worn_02", 0.28, Color(0.38, 0.39, 0.42))


	_mat_track = _pbr("concrete_floor_worn_02", 0.55, Color(0.6, 0.53, 0.44))
	_mat_track.roughness = 1.0

	_mat_wood = _pbr("rough_wood", 1.1, Color(0.52, 0.44, 0.34))


func _slab(size: Vector3, pos: Vector3, mat: Material, collide:= false) -> MeshInstance3D:
	var mesh:= BoxMesh.new()
	mesh.size = size
	var mi:= MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		var body:= StaticBody3D.new()
		body.collision_layer = Cfg.L_WORLD
		body.collision_mask = 0
		var cs:= CollisionShape3D.new()
		var shape:= BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi


func _scatter(mesh: Mesh, mat: Material, xforms: Array [Transform3D],
		shadows:= true) -> MultiMeshInstance3D:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms [i])
	var mmi:= MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _cylinder(radius: float, height: float, sides:= 12) -> CylinderMesh:
	var m:= CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m


func _build_pad() -> void:
	_slab(Vector3(PAD_HALF * 2.0, 0.5, PAD_OUT), Vector3(0.0, -0.25, PAD_OUT * 0.5),
		_mat_pad, true)


	_slab(Vector3(PAD_HALF * 2.0 + 3.0, 0.06, 2.4), Vector3(0.0, -0.06, PAD_OUT + 0.4),
		_mat_track)


func _build_fence() -> void:
	var run_z0:= PAD_OUT + 1.0
	var x:= TRACK_FENCE_HALF
	var run_z1:= 96.0
	var posts: Array [Transform3D] = []
	var mesh:= _cylinder(0.075, FENCE_H, 6)
	for sgn: float in [-1.0, 1.0]:

		var n:= int((run_z1 - CORRIDOR_OUT) / POST_GAP)
		for i in n + 1:
			var z:= CORRIDOR_OUT + i * POST_GAP
			posts.append(Transform3D(Basis.IDENTITY,
				Vector3(sgn * x, GROUND_Y + FENCE_H * 0.5, z)))
		for h: float in [0.42, 0.92]:
			_slab(Vector3(0.09, 0.1, run_z1 - CORRIDOR_OUT),
				Vector3(sgn * x, GROUND_Y + h, (CORRIDOR_OUT + run_z1) * 0.5),
				_mat_wood, true)
	_scatter(mesh, _mat_wood, posts)

	var pen:= YardFence.new()
	pen.name = "YardFence"
	pen.wall_x0 = wall_x0
	pen.wall_x1 = wall_x1
	pen.shed_depth = shed_depth
	pen.reach_out = run_z0
	pen.reach_half = PAD_HALF


	pen.gate_w = ROAD_W + 1.0
	pen.corridor_half = TRACK_FENCE_HALF
	pen.corridor_out = CORRIDOR_OUT
	pen.fog_from = FOG_FROM
	pen.ground_y = GROUND_Y
	add_child(pen)
	pen.build()
