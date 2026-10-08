class_name BrutalistPlaza
extends Node3D


const SCALE:= 1.0


const MASSING_SCENE:= "res://scenes/brutalist_plaza.tscn"


const SUN_NODE:= "Sun"
const ENV_NODE:= "SiteEnvironment"
const EDITOR_NODE:= "EditorOnly"


const TUNNEL_NODE:= "Tunnel"


const BLOCKER_NODE:= "Blocker"


const SIDE_NODES:= ["Side_L", "Side_R"]
const BACK_NODE:= "Back"


const SUN_PREFIXES:= ["light_", "shadow_", "directional_shadow_", "distance_fade_"]


const ENV_PROPERTIES:= [
	"fog_enabled", "fog_light_color", "fog_light_energy", "fog_density",
	"fog_sky_affect", "fog_height", "fog_height_density", "fog_aerial_perspective",
	"volumetric_fog_enabled", "volumetric_fog_density", "volumetric_fog_albedo",
	"volumetric_fog_emission", "volumetric_fog_length", "volumetric_fog_sky_affect",
	"ambient_light_color", "ambient_light_energy",
]


const TAKE_AWAY_ONLY:= ["fog_enabled", "volumetric_fog_enabled", "sdfgi_enabled"]


var massing: Node3D


var _authored_sun: DirectionalLight3D
var _authored_env: Environment


var tunnel: Node3D


var _blocker: StaticBody3D


var _said_it:= false

var _scale:= SCALE


func build(scale_factor: float = SCALE) -> void:
	_scale = scale_factor
	var packed:= load(MASSING_SCENE) as PackedScene
	if packed == null:
		push_error("BrutalistPlaza: no massing scene at %s" % MASSING_SCENE)
		return
	massing = packed.instantiate() as Node3D
	massing.name = "Massing"
	_take_authoring(massing)
	add_child(massing)


	massing.scale = Vector3.ONE * _scale
	for mi: MeshInstance3D in masses():
		_retile(mi)
		_collide(mi)


	if tunnel != null:
		add_child(tunnel)
		for mi: MeshInstance3D in _tunnel_meshes():
			_collide(mi)


func _take_authoring(root: Node3D) -> void:
	var lamp:= root.get_node_or_null(SUN_NODE) as DirectionalLight3D
	if lamp != null:
		root.remove_child(lamp)
		_authored_sun = lamp
	var env_node:= root.get_node_or_null(ENV_NODE) as WorldEnvironment
	if env_node != null:
		_authored_env = env_node.environment
		root.remove_child(env_node)
		env_node.free()
	var props:= root.get_node_or_null(EDITOR_NODE)
	if props != null:
		root.remove_child(props)
		props.free()


	var bore:= root.get_node_or_null(TUNNEL_NODE) as Node3D
	if bore != null:
		root.remove_child(bore)


		var stack: Array [Node] = [bore]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			node.owner = null
			for kid: Node in node.get_children():
				stack.append(kid)
		tunnel = bore


func _exit_tree() -> void:
	if _authored_sun != null:
		_authored_sun.free()
		_authored_sun = null


func masses() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if massing == null:
		return out
	var stack: Array [Node] = [massing]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			out.append(node as MeshInstance3D)
		for child: Node in node.get_children():
			stack.append(child)
	return out


func _tunnel_meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if tunnel == null:
		return out
	for kid: Node in tunnel.get_children():
		if kid is MeshInstance3D:
			out.append(kid as MeshInstance3D)
	return out


func seat_tunnel(door: Node3D) -> void:
	if tunnel == null or door == null or not door.is_inside_tree():
		return
	tunnel.global_transform = door.global_transform


func hold_the_doorway(on: bool) -> void:
	if _blocker == null:
		return
	_blocker.collision_layer = Cfg.L_PEN if on else 0


func in_the_bore(p: Vector3) -> bool:
	if tunnel == null or not tunnel.is_inside_tree():
		return false
	var local:= tunnel.to_local(p)


	if local.z > 0.0:
		return false
	var half:= INF
	for node_name: String in SIDE_NODES:
		var side:= tunnel.get_node_or_null(node_name) as MeshInstance3D
		if side == null or side.mesh == null:
			continue
		var box:= side.mesh.get_aabb()
		half = minf(half, absf(side.position.x + box.get_center().x)
			- box.size.x * 0.5)
	if is_inf(half):
		return false
	var deep:= 0.0
	var back:= tunnel.get_node_or_null(BACK_NODE) as MeshInstance3D
	if back != null and back.mesh != null:
		var box:= back.mesh.get_aabb()
		deep = absf(back.position.z + box.get_center().z) - box.size.z * 0.5
	return absf(local.x) <= half and local.z >= - deep


func light_it(sun: DirectionalLight3D, env: Environment) -> void:
	_aim_the_sun(sun)
	_set_the_air(env)


func _aim_the_sun(sun: DirectionalLight3D) -> void:
	if sun == null:
		return
	if _authored_sun == null:
		push_warning("BrutalistPlaza: no '%s' in %s, leaving the world's sun alone"
			% [SUN_NODE, MASSING_SCENE])
		return


	sun.global_transform = Transform3D(_authored_sun.transform.basis,
		sun.global_position)


	var shadows:= sun.shadow_enabled
	for prop: Dictionary in _authored_sun.get_property_list():
		if int(prop ["usage"]) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var key:= String(prop ["name"])
		for prefix: String in SUN_PREFIXES:
			if key.begins_with(prefix):
				sun.set(key, _authored_sun.get(key))
				break
	sun.shadow_enabled = shadows and _authored_sun.shadow_enabled
	if _said_it:
		return

	var up:= _authored_sun.transform.basis.z.normalized().y
	print("[plaza] sun %.0f deg, energy %.1f, shadows to %.0f m"
		% [rad_to_deg(asin(up)), sun.light_energy,
			sun.directional_shadow_max_distance])


func _set_the_air(env: Environment) -> void:
	if env == null:
		return
	if _authored_env == null:
		push_warning("BrutalistPlaza: no '%s' in %s, leaving the world's air alone"
			% [ENV_NODE, MASSING_SCENE])
		return


	var live:= { }
	for key: String in TAKE_AWAY_ONLY:
		live [key] = bool(env.get(key))
	for key: String in ENV_PROPERTIES:
		env.set(key, _authored_env.get(key))
	for key: String in TAKE_AWAY_ONLY:
		env.set(key, live [key] and bool(_authored_env.get(key)))
	if _said_it:
		return
	_said_it = true
	print("[plaza] fog %s, volumetric fog %s, ambient %.2f"
		% ["on" if env.fog_enabled else "off",
			"on" if env.volumetric_fog_enabled else "off",
			env.ambient_light_energy])


func _collide(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var aabb:= mi.mesh.get_aabb()
	var size:= aabb.size
	var centre:= aabb.get_center()


	if size.y < 0.01:
		size.y = 1.0
		centre.y -= 0.5

	var body:= StaticBody3D.new()
	body.name = "%s_body" % mi.name


	if mi.name == BLOCKER_NODE:
		body.collision_layer = Cfg.L_PEN
		_blocker = body
	var shape:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	body.add_child(shape)
	mi.add_child(body)


func _retile(mi: MeshInstance3D) -> void:
	if is_equal_approx(_scale, 1.0) or mi.mesh == null or mi.mesh is PlaneMesh:
		return
	var mat:= mi.mesh.surface_get_material(0) as StandardMaterial3D
	if mat == null or not mat.uv1_world_triplanar:
		return


	var own:= mat.duplicate() as StandardMaterial3D
	own.uv1_scale = mat.uv1_scale / _scale
	mi.material_override = own
