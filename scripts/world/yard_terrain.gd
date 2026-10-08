class_name YardTerrain
extends Node3D


const SCENE:= "res://scenes/yard_terrain.tscn"
const DATA_DIR:= "res://assets/terrain/yard"


const RES:= 1024
const CELL:= 2.0


const REGION_SIZE:= 256

const HALF:= RES * CELL * 0.5


const FLAT_R:= 84.0

const BLEND:= 76.0


const TRACK_HALF:= 14.0
const TRACK_RUN:= 330.0


var track_yaw:= 0.0


var centre:= Vector3.ZERO

var _terrain: Terrain3D
var _flora: YardFlora

## Mobile path: engine-native ground instead of Terrain3D (whose gdextension
## compute/instancer path is what stalls Mali-class phones during load).
var native_ground:= false

## Amplitude of the gentle hills outside the flat yard ring, in metres.
const HILL_HEIGHT:= 5.0

## Albedo used for the native ground (the same scan the Terrain3D build uses).
const GROUND_TEX:= "res://demo/assets/textures/ground037_alb_ht.png"
const GROUND_NRM:= "res://demo/assets/textures/ground037_nrm_rgh.png"


const SOLID_SAMPLES:= 129
var _solid: StaticBody3D


func _ready() -> void:
	if Cfg.is_mobile:
		native_ground = true
		_build_native_ground()
		return
	var packed: PackedScene = load(SCENE)
	if packed == null:
		push_error("YardTerrain: %s is missing. Bake one with --yardbake." % SCENE)
		return
	var root:= packed.instantiate()
	_terrain = root.get_node_or_null("Terrain3D")


	if _terrain != null:
		_terrain.collision_mode = Terrain3DCollision.DISABLED
	add_child(root)
	if _terrain == null:
		push_error("YardTerrain: %s has no Terrain3D node in it" % SCENE)
		return
	if _terrain.data == null or _terrain.data.get_region_count() == 0:
		push_error("YardTerrain: no regions under %s. Bake one with --yardbake." % DATA_DIR)
		return
	_build_solid()


## Engine-native ground for mobile: a relief-displaced plane plus the same
## HeightMapShape3D collision the Terrain3D path builds. Pure CPU math, no
## gdextension nodes, no compute shaders, no instancer -- runs on every device.
func _build_native_ground() -> void:
	var n:= SOLID_SAMPLES
	var half:= (n - 1) * 0.5
	var heights:= PackedFloat32Array()
	heights.resize(n * n)
	for z in n:
		for x in n:
			var at:= centre + Vector3((x - half) * CELL, 0.0, (z - half) * CELL)
			heights [z * n + x] = _native_height(at)

	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in n - 1:
		for x in n - 1:
			var x0: float = (x - half) * CELL
			var z0: float = (z - half) * CELL
			var x1: float = x0 + CELL
			var z1: float = z0 + CELL
			var h00: float = heights [z * n + x]
			var h10: float = heights [z * n + x + 1]
			var h01: float = heights [(z + 1) * n + x]
			var h11: float = heights [(z + 1) * n + x + 1]
			var u0: float = float(x) / float(n - 1)
			var u1: float = float(x + 1) / float(n - 1)
			var v0: float = float(z) / float(n - 1)
			var v1: float = float(z + 1) / float(n - 1)
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(Vector3(x0, h00, z0))
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(Vector3(x0, h01, z1))
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(Vector3(x1, h11, z1))
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(Vector3(x0, h00, z0))
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(Vector3(x1, h11, z1))
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(Vector3(x1, h10, z0))
	st.generate_normals()
	st.generate_tangents()
	var mi:= MeshInstance3D.new()
	mi.name = "NativeGround"
	mi.mesh = st.commit()
	mi.material_override = _native_material()
	mi.position = Vector3(centre.x, 0.0, centre.z)
	add_child(mi)

	_build_solid_from(heights)

	# Height/flora queries fall back to the native formulas below.
	_terrain = null
	_flora = null


func _native_height(world: Vector3) -> float:
	# The Terrain3D bake is flat inside the yard ring; outside it rolls away
	# with the same smoothstep relief the rest of the game reasons about.
	return YardGround.GROUND_Y + relief_at(world, track_yaw) * HILL_HEIGHT


func _native_material() -> StandardMaterial3D:
	var mat:= StandardMaterial3D.new()
	var alb: Texture2D = load(GROUND_TEX)
	if alb != null:
		mat.albedo_texture = alb
		var nrm: Texture2D = load(GROUND_NRM)
		if nrm != null:
			mat.normal_enabled = true
			mat.normal_texture = nrm
		mat.uv1_scale = Vector3(96.0, 96.0, 1.0)
	mat.albedo_color = Color(0.78, 0.74, 0.62)
	mat.roughness = 0.95
	return mat


func _build_solid_from(heights: PackedFloat32Array) -> void:
	var shape:= HeightMapShape3D.new()
	shape.map_width = SOLID_SAMPLES
	shape.map_depth = SOLID_SAMPLES
	shape.map_data = heights
	var cs:= CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3.ONE * CELL
	_solid = StaticBody3D.new()
	_solid.name = "Ground"
	_solid.collision_layer = Cfg.L_WORLD
	_solid.collision_mask = 0
	_solid.position = Vector3(centre.x, 0.0, centre.z)
	_solid.add_child(cs)
	add_child(_solid)


func _build_solid() -> void:
	var n:= SOLID_SAMPLES
	var half:= (n - 1) * 0.5
	var heights:= PackedFloat32Array()
	heights.resize(n * n)
	for z in n:
		for x in n:
			var at:= centre + Vector3((x - half) * CELL, 0.0, (z - half) * CELL)
			var h:= _terrain.data.get_height(at)
			heights [z * n + x] = (YardGround.GROUND_Y if is_nan(h) else h) / CELL
	var shape:= HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = heights
	var cs:= CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3.ONE * CELL
	_solid = StaticBody3D.new()
	_solid.name = "Ground"
	_solid.collision_layer = Cfg.L_WORLD
	_solid.collision_mask = 0
	_solid.position = Vector3(centre.x, 0.0, centre.z)
	_solid.add_child(cs)
	add_child(_solid)


func solid() -> StaticBody3D:
	return _solid


static func build_material(m: Terrain3DMaterial) -> Terrain3DMaterial:


	m.world_background = Terrain3DMaterial.NONE
	m.auto_shader = false
	m.dual_scaling = false


	m.set_shader_param("enable_macro_variation", true)
	m.set_shader_param("macro_variation1", Color(0.86, 0.88, 0.82, 1.0))
	m.set_shader_param("macro_variation2", Color(0.9, 0.87, 0.76, 1.0))
	m.set_shader_param("macro_variation_slope", 0.3)
	m.set_shader_param("noise1_scale", 0.035)
	m.set_shader_param("noise1_angle", 0.1)
	m.set_shader_param("noise2_scale", 0.088)


	m.set_shader_param("enable_projection", true)
	m.set_shader_param("projection_threshold", 0.8)
	m.set_shader_param("tri_scale_reduction", 0.3)

	m.set_shader_param("blend_sharpness", 0.72)
	m.set_shader_param("mipmap_bias", 1.0)
	m.set_shader_param("depth_blur", 0.0)


	m.set_shader_param("world_noise_height", 26.0)
	m.set_shader_param("world_noise_scale", 7.4)
	m.set_shader_param("world_noise_offset", Vector3(2.1, -0.4, 1.7))
	m.set_shader_param("world_noise_min_octaves", 2)
	m.set_shader_param("world_noise_max_octaves", 4)


	m.set_shader_param("world_noise_region_blend", 0.4)
	m.set_shader_param("world_noise_lod_distance", 3000.0)
	return m


func _plant() -> void:
	_flora = YardFlora.new()
	_flora.terrain = _terrain
	_flora.track_yaw = track_yaw
	_flora.sow()


static func relief_at(world: Vector3, yaw: float) -> float:


	var u:= world.x * sin(yaw) + world.z * cos(yaw)
	var v:= world.x * cos(yaw) - world.z * sin(yaw)
	var radial:= Vector2(u, v).length() - FLAT_R
	var along:= maxf(absf(v) - TRACK_HALF, u - TRACK_RUN)
	return smoothstep(0.0, BLEND, minf(radial, along))


static func required_flat() -> float:
	return Warehouse.INNER + _widest_extra() + YardGround.PAD_OUT + 4.0


static func required_run() -> float:
	return Warehouse.INNER + _widest_extra() + Warehouse.WALL_T + YardGround.ROAD_END


static func _widest_extra() -> float:
	return Tech.YARD_METRES_PER_RANK * float(TechTree.max_rank("yard_space"))


func terrain() -> Terrain3D:
	return _terrain


func flora() -> YardFlora:
	return _flora


func height_at(world: Vector3) -> float:
	if native_ground:
		return _native_height(world)
	if _terrain == null or _terrain.data == null:
		return YardGround.GROUND_Y
	var h: float = _terrain.data.get_height(world)


	return YardGround.GROUND_Y if is_nan(h) else h
