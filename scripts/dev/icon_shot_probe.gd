class_name DevIconShotProbe
extends Node


const OUT_DIR:= "res://docs/tech_tree/from_game"


const CELL:= 512


const EYE_DIR:= Vector3(5.0, 4.4, 6.4)


const FRAME:= 1.12


const STAGE:= Vector3(600.0, 0.0, 600.0)
const STAGE_STEP:= 60.0


const POUR_HEIGHT:= 0.3
const POUR_TIME:= 1.2


const STUB:= 1.0


const SKIP_NAMES:= ["Range", "Marker_", "Col_", "Ghost", "Alert", "Fault",
	"Sign", "Highlight", "Throw", "Steam", "Aim", "Beam", "Halo", "Label"]


const SHEET_COLS:= 6


const DOWNLOADED:= {
	"boots": "res://assets/downloaded/models/rubber_boots/rubber_boots_1k.gltf",
	"gloves": "res://assets/downloaded/models/garden_gloves_01/garden_gloves_01_1k.gltf",
	"tape_measure": "res://assets/downloaded/models/measuring_tape_01/measuring_tape_01_1k.gltf",


	"step_ladder": "res://assets/downloaded/models/step_ladder/step_ladder.glb",
	"feathers": "res://assets/downloaded/models/feathers/feathers.glb",
	"winged_shoe": "res://assets/downloaded/models/winged_shoe/winged_shoe.glb",
	"anvil": "res://assets/downloaded/models/anvil/anvil.glb",
	"water_bottle": "res://assets/downloaded/models/water_bottle/water_bottle.glb",
	"dumbbell": "res://assets/downloaded/models/dumbbell/dumbbell.glb",
}


const DOWNLOADED_DROP:= {
	"boots": ["rubber_boots_l", "rubber_boots_r"],


	"feathers": ["feather_a_geather_a"],
}


const HAY_STRANDS:= 120
const HAY_SCATTER:= 0.22


const STACK_ACROSS:= 3
const STACK_LAYERS:= 4

var world: Node3D
var player: Player

var _view: SubViewport
var _cam: Camera3D
var _lamps: Array [Node3D] = []
var _key: DirectionalLight3D


var _key_dir:= Vector3.UP
var _live: Array [Node] = []


var _pad:= AABB()


var _base_exposure:= 1.0


var _stage:= STAGE


var _long_dir:= Vector3.ZERO


var _eye:= EYE_DIR


const SUBJECTS:= [


	{ "id": "spade", "group": "tools", "diag": true, "stops": -0.35, "head": true,
		"crop": 0.44 },
	{ "id": "toy_shovel", "group": "tools", "diag": true, "stops": 0.0 },
	{ "id": "pitchfork", "group": "tools", "diag": true, "stops": 0.0, "head": true,
		"crop": 0.44 },
	{ "id": "broom", "group": "tools", "diag": true, "stops": 0.0, "head": true,
		"crop": 0.44 },


	{ "id": "metal_detector", "group": "tools", "diag": true, "stops": -0.5,
		"yaw": 180.0 },


	{ "id": "yard_vac", "group": "tools", "diag": true, "stops": -0.2,
		"yaw": 145.0 },


	{ "id": "lighter", "group": "tools", "diag": false, "stops": -0.5,
		"yaw": 30.0 },
	{ "id": "bucket", "group": "tools", "diag": false, "stops": 0.0 },
	{ "id": "bucket_full", "group": "tools", "diag": false, "stops": 0.0 },
	{ "id": "bucket_pour", "group": "tools", "diag": false, "stops": -0.4 },


	{ "id": "wheelbarrow", "group": "tools", "diag": false, "stops": 0.0,
		"yaw": -28.0 },
	{ "id": "wheelbarrow_full", "group": "tools", "diag": false, "stops": 0.0,
		"yaw": -28.0 },


	{ "id": "hay_wad", "group": "goods", "diag": false, "stops": 0.0 },
	{ "id": "hay_bale", "group": "goods", "diag": false, "stops": 0.0 },
	{ "id": "foiled_bale", "group": "goods", "diag": false, "stops": 0.0 },
	{ "id": "eco_brick", "group": "goods", "diag": false, "stops": 0.0 },
	{ "id": "strand", "group": "goods", "diag": true, "stops": 0.0 },
	{ "id": "needle", "group": "goods", "diag": true, "stops": 0.0 },


	{ "id": "hay_pulp", "group": "goods", "diag": false, "stops": 0.0 },
	{ "id": "paper_roll", "group": "goods", "diag": false, "stops": 0.0 },


	{ "id": "feed_disc", "group": "goods", "diag": false, "stops": 0.0 },


	{ "id": "platform", "group": "structure", "diag": false, "stops": 0.0 },
	{ "id": "railing", "group": "structure", "diag": false, "stops": 0.0 },
	{ "id": "stairs", "group": "structure", "diag": false, "stops": 0.0 },
	{ "id": "wall", "group": "structure", "diag": false, "stops": 0.0 },
	{ "id": "wall_window", "group": "structure", "diag": false, "stops": 0.0 },
	{ "id": "wall_door", "group": "structure", "diag": false, "stops": 0.0 },


	{ "id": "roof", "group": "structure", "diag": false, "stops": 1.0 },
	{ "id": "roof_pitch", "group": "structure", "diag": false, "stops": 1.0 },
	{ "id": "roof_hatch", "group": "structure", "diag": false, "stops": 1.0 },
	{ "id": "beam", "group": "structure", "diag": true, "stops": 0.0 },
	{ "id": "beam_stack", "group": "structure", "diag": false, "stops": 0.0 },


	{ "id": "belt", "group": "flow", "diag": false, "stops": 0.0 },
	{ "id": "belt_loaded", "group": "flow", "diag": false, "stops": 0.0 },


	{ "id": "enclosed_belt", "group": "flow", "diag": false, "stops": 0.2 },
	{ "id": "splitter", "group": "flow", "diag": false, "stops": 0.0 },
	{ "id": "joiner", "group": "flow", "diag": false, "stops": 0.0 },
	{ "id": "u_splitter", "group": "flow", "diag": false, "stops": 0.0 },
	{ "id": "u_joiner", "group": "flow", "diag": false, "stops": 0.0 },
	{ "id": "t_splitter", "group": "flow", "diag": false, "stops": 0.0 },
	{ "id": "compact_splitter", "group": "flow", "diag": false, "stops": 0.0 },
	{ "id": "smart_splitter", "group": "flow", "diag": false, "stops": 0.0 },
	{ "id": "compressor", "group": "flow", "diag": false, "stops": 0.0 },
	{ "id": "wrapper", "group": "flow", "diag": false, "stops": 0.0 },
	{ "id": "silo", "group": "flow", "diag": false, "stops": 0.0 },
	{ "id": "pelletizer", "group": "flow", "diag": false, "stops": 0.0 },


	{ "id": "tube_launcher", "group": "flow", "diag": false, "stops": 0.0,
		"yaw": -55.0 },
	{ "id": "hay_stairs", "group": "flow", "diag": false, "stops": 0.0 },


	{ "id": "hay_lift", "group": "flow", "diag": false, "stops": 0.35,
		"yaw": 90.0 },
	{ "id": "piston_rake", "group": "flow", "diag": false, "stops": 0.0 },


	{ "id": "dump_hatch", "group": "flow", "diag": false, "stops": 0.0,
		"yaw": -48.0 },


	{ "id": "generator", "group": "flow", "diag": false, "stops": 0.0,
		"yaw": 90.0 },


	{ "id": "gas_plant", "group": "flow", "diag": false, "stops": 0.0,
		"yaw": 90.0 },
	{ "id": "power_pole", "group": "flow", "diag": false, "stops": 0.0 },


	{ "id": "power_box", "group": "flow", "diag": false, "stops": 1.0,
		"yaw": 0.0 },


	{ "id": "borehole", "group": "water", "diag": false, "stops": 0.0,
		"yaw": 90.0 },


	{ "id": "water_main", "group": "water", "diag": false, "stops": 0.0,
		"yaw": 90.0 },


	{ "id": "water_splitter", "group": "water", "diag": false, "stops": 0.0,
		"yaw": -90.0 },


	{ "id": "pulper", "group": "flow", "diag": false, "stops": 0.0,
		"yaw": 90.0 },


	{ "id": "paper_machine", "group": "flow", "diag": false, "stops": 0.35,
		"yaw": 90.0 },


	{ "id": "briquette_press", "group": "flow", "diag": false, "stops": 0.35,
		"yaw": 90.0 },


	{ "id": "arm", "group": "automation", "diag": false, "stops": 0.0 },
	{ "id": "arm_long", "group": "automation", "diag": false, "stops": 0.0 },
	{ "id": "arm_carry", "group": "automation", "diag": false, "stops": 0.0 },
	{ "id": "drone", "group": "automation", "diag": false, "stops": 0.0 },


	{ "id": "scanner", "group": "prospecting", "diag": false, "stops": 0.0 },
	{ "id": "cabinet", "group": "prospecting", "diag": false, "stops": 0.0 },
	{ "id": "cabinet_open", "group": "prospecting", "diag": false, "stops": 0.0 },


	{ "id": "needle_radar", "group": "prospecting", "diag": false, "stops": 0.0 },


	{ "id": "paintboard", "group": "structure", "diag": false, "stops": 0.0 },


	{ "id": "work_lamp", "group": "structure", "diag": false, "stops": -0.75 },


	{ "id": "selling_stand", "group": "world", "diag": false, "stops": 0.0 },
	{ "id": "shop", "group": "world", "diag": false, "stops": 0.0 },
	{ "id": "door", "group": "world", "diag": false, "stops": 0.0 },


	{ "id": "boots", "group": "ability", "diag": false, "stops": 0.0 },
	{ "id": "boots_hay", "group": "ability", "diag": false, "stops": 0.0 },
	{ "id": "gloves", "group": "ability", "diag": false, "stops": 0.0 },


	{ "id": "tape_measure", "group": "ability", "diag": false, "stops": 0.5 },
	{ "id": "step_ladder", "group": "ability", "diag": false, "stops": 0.0 },
	{ "id": "feathers", "group": "ability", "diag": true, "stops": 0.0 },
	{ "id": "winged_shoe", "group": "ability", "diag": false, "stops": 0.0 },
	{ "id": "anvil", "group": "ability", "diag": false, "stops": 0.0 },
	{ "id": "water_bottle", "group": "ability", "diag": false, "stops": 0.0 },
	{ "id": "dumbbell", "group": "ability", "diag": false, "stops": 0.0 },


	{ "id": "pitchfork_swing", "group": "tools", "diag": true, "stops": 0.0, "head": true,
		"crop": 0.6, "roll": 90.0 },


	{ "id": "warehouse", "group": "world", "diag": false, "stops": -1.5,
		"eye": Vector3(5.0, 1.25, 6.4) },
	{ "id": "warehouse_wide", "group": "world", "diag": false, "stops": -1.5,
		"eye": Vector3(5.0, 1.25, 6.4) },
]


func shoot(out_dir: String, only: Array) -> void:
	world.set("block_save", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	while Loading.is_active():
		await get_tree().process_frame
	await _wait(0.5)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_build_stage()

	var shot_names: Array [String] = []
	var slot:= 0
	for spec: Dictionary in SUBJECTS:
		var id:= str(spec ["id"])
		if not only.is_empty() and not (id in only):
			continue
		print("[iconshots] %s" % id)
		_stage = STAGE + Vector3(STAGE_STEP * float(slot), 0.0, 0.0)
		slot += 1
		var nodes:= await _build(id)
		if nodes.is_empty():
			push_warning("[iconshots] %s built nothing -- skipped" % id)
			_clear()
			continue


		for i in 3:
			await get_tree().process_frame
		_hush(nodes)


		_eye = spec.get("eye", EYE_DIR)
		_aim_lamps()
		var crop:= float(spec.get("crop", 0.0))
		if bool(spec.get("diag", false)):
			_lay_diagonal(nodes, bool(spec.get("head", false)), crop > 0.0)
		_yaw(nodes, float(spec.get("yaw", 0.0)))
		_roll(nodes, float(spec.get("roll", 0.0)))
		var box:= _head_box(nodes, crop) if crop > 0.0 else _aabb_of(nodes)
		if _pad.size.length() > 0.0:
			box = box.merge(_pad)
		if box.size.length() <= 0.0:
			push_warning("[iconshots] %s framed to nothing -- skipped" % id)
			_clear()
			continue
		_aim(box)
		_light(box)
		_expose(float(spec.get("stops", 0.0)))
		await _capture("%s/%s.png" % [out_dir, id])
		shot_names.append(id)
		_clear()

	_contact_sheet(out_dir)
	print("[iconshots] %d icons in %s" % [shot_names.size(), out_dir])
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _build_stage() -> void:
	world.sun.visible = false
	world.fill.visible = false


	var sky_fill:= world.get_node_or_null("SkyFill") as DirectionalLight3D
	if sky_fill != null:
		sky_fill.visible = false


	if world.terrain != null:
		world.terrain.visible = false

	_view = SubViewport.new()
	_view.name = "IconView"
	_view.size = Vector2i(CELL, CELL)
	_view.own_world_3d = false
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)

	_cam = Camera3D.new()
	_cam.name = "IconCam"
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 0.05
	_cam.far = 400.0
	_cam.environment = _icon_environment()
	_base_exposure = _cam.environment.tonemap_exposure
	_view.add_child(_cam)

	_build_lights()
	_build_floor()
	_reach_strands()


func _build_floor() -> void:
	var body:= StaticBody3D.new()
	body.name = "IconGround"
	body.collision_layer = Cfg.L_WORLD
	body.collision_mask = 0
	var shape:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	var span:= STAGE_STEP * float(SUBJECTS.size() + 2)
	box.size = Vector3(span, 2.0, 120.0)
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)


	body.global_position = STAGE + Vector3(span * 0.5 - STAGE_STEP, -1.0, 0.0)


func _reach_strands() -> void:
	var live = world.get("live")
	if live == null:
		return
	var mmi:= live.get("_mmi") as MultiMeshInstance3D
	if mmi == null:
		push_warning("[iconshots] no strand MultiMesh -- the pour will not draw")
		return
	var last:= STAGE + Vector3(STAGE_STEP * float(SUBJECTS.size()), 0.0, 0.0)
	var box:= mmi.custom_aabb.expand(STAGE - Vector3(12, 12, 12))
	mmi.custom_aabb = box.expand(last + Vector3(12, 12, 12))


func _icon_environment() -> Environment:
	var src: Environment = (world.get("env_node") as WorldEnvironment).environment
	var env: Environment = src.duplicate(true)
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY


	env.fog_enabled = false
	env.volumetric_fog_enabled = false


	env.sdfgi_enabled = false
	return env


const LAMP_RIG:= [


	Vector3(-1.1, 1.5, 0.9),


	Vector3(1.9, 0.35, 0.8),


	Vector3(0.5, 1.3, -2.0),
]


func _build_lights() -> void:
	_key = _sun(LAMP_RIG [0], Color(1.0, 0.94, 0.85), 2.6, true)
	_sun(LAMP_RIG [1], Color(0.78, 0.85, 1.0), 0.85, false)
	_sun(LAMP_RIG [2], Color(1.0, 0.97, 0.92), 1.5, false)
	_aim_lamps()


func _aim_lamps() -> void:
	var basis:= _screen_basis()
	for i in _lamps.size():
		var c: Vector3 = LAMP_RIG [i]
		var dir:= (basis.x * c.x + basis.y * c.y + basis.z * c.z).normalized()
		if i == 0:
			_key_dir = dir
		_lamps [i].look_at_from_position(dir * 40.0, Vector3.ZERO, Vector3.UP)


func _sun(_coeffs: Vector3, colour: Color, energy: float,
		shadow: bool) -> DirectionalLight3D:
	var l:= DirectionalLight3D.new()
	l.light_color = colour
	l.light_energy = energy
	l.light_angular_distance = 1.4
	l.shadow_enabled = shadow
	l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	l.shadow_bias = 0.015
	l.shadow_normal_bias = 0.6
	world.add_child(l)
	_lamps.append(l)
	return l


func _light(box: AABB) -> void:
	if _key == null:
		return
	var radius:= maxf(box.size.length() * 0.5, 0.3)
	_key.global_position = box.get_center() + _key_dir * radius * 8.0
	_key.directional_shadow_max_distance = radius * 20.0


func _expose(stops: float) -> void:
	_cam.environment.tonemap_exposure = _base_exposure * pow(2.0, stops)


func _screen_basis() -> Basis:
	return Transform3D().looking_at(- _eye.normalized(), Vector3.UP).basis


func _aim(box: AABB) -> void:
	var basis:= _screen_basis()
	var centre:= box.get_center()
	var radius:= maxf(box.size.length() * 0.5, 0.2)
	_cam.global_transform = Transform3D(basis, centre + basis.z * (radius * 6.0 + 4.0))
	var span:= Vector2.ZERO
	for i in 8:
		var corner:= box.position + box.size * Vector3(
			float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1))
		var q:= corner - centre
		span.x = maxf(span.x, absf(q.dot(basis.x)))
		span.y = maxf(span.y, absf(q.dot(basis.y)))
	_cam.size = maxf(span.x, span.y) * 2.0 * FRAME
	_cam.far = radius * 20.0 + 40.0


func _lay_diagonal(nodes: Array, head_forward: bool = false,
		cropped: bool = false) -> void:
	var box:= _aabb_of(nodes)
	if box.size.length() <= 0.0:
		return
	var axis:= Vector3.RIGHT
	if box.size.y >= box.size.x and box.size.y >= box.size.z:
		axis = Vector3.UP
	elif box.size.z >= box.size.x:
		axis = Vector3.BACK
	var basis:= _screen_basis()
	var target:= (basis.x * 0.7071 + basis.y * 0.7071).normalized()
	if head_forward:


		axis *= _head_sign(nodes, axis, box.get_center())
		if not cropped:


			target = (basis.z * 0.8 - basis.y * 0.38 - basis.x * 0.46).normalized()


	_long_dir = target
	var turn:= Basis(Quaternion(axis, target))
	var centre:= box.get_center()
	for node: Node in nodes:
		var n3:= node as Node3D
		if n3 == null:
			continue
		var t:= n3.global_transform
		n3.global_transform = Transform3D(turn * t.basis,
			centre + turn * (t.origin - centre))


func _roll(nodes: Array, degrees: float) -> void:
	if is_zero_approx(degrees):
		return
	var box:= _aabb_of(nodes)
	if box.size.length() <= 0.0:
		return
	var turn:= Basis(_screen_basis().z, deg_to_rad(degrees))
	var centre:= box.get_center()
	for node: Node in nodes:
		var n3:= node as Node3D
		if n3 == null:
			continue
		var t:= n3.global_transform
		n3.global_transform = Transform3D(turn * t.basis,
			centre + turn * (t.origin - centre))
	_long_dir = turn * _long_dir


func _yaw(nodes: Array, degrees: float) -> void:
	if is_zero_approx(degrees):
		return
	var box:= _aabb_of(nodes)
	if box.size.length() <= 0.0:
		return
	var turn:= Basis(Vector3.UP, deg_to_rad(degrees))
	var centre:= box.get_center()
	for node: Node in nodes:
		var n3:= node as Node3D
		if n3 == null:
			continue
		var t:= n3.global_transform
		n3.global_transform = Transform3D(turn * t.basis,
			centre + turn * (t.origin - centre))


func _head_sign(nodes: Array, axis: Vector3, centre: Vector3) -> float:
	var widest:= [0.0, 0.0]
	for node: Node in nodes:
		for vis: VisualInstance3D in _visuals(node):
			var mi:= vis as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var xf:= mi.global_transform
			for surface in mi.mesh.get_surface_count():
				var arrays:= mi.mesh.surface_get_arrays(surface)
				if arrays.size() <= Mesh.ARRAY_VERTEX:
					continue
				var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]


				var step:= maxi(1, verts.size() / 400)
				var i:= 0
				while i < verts.size():
					var p: Vector3 = (xf * verts [i]) - centre
					var along:= p.dot(axis)
					var off:= (p - axis * along).length()
					var half:= 1 if along >= 0.0 else 0
					widest [half] = maxf(widest [half], off)
					i += step
	return 1.0 if widest [1] >= widest [0] else -1.0


func _head_box(nodes: Array, frac: float) -> AABB:
	var whole:= _aabb_of(nodes)
	if _long_dir.length_squared() <= 0.0 or whole.size.length() <= 0.0:
		return whole
	var dir:= _long_dir.normalized()


	var reach:= 0.0
	var centre:= whole.get_center()
	for i in 8:
		var corner:= whole.position + whole.size * Vector3(
			float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1))
		reach = maxf(reach, absf((corner - centre).dot(dir)))
	var cut:= reach * (1.0 - 2.0 * clampf(frac, 0.05, 1.0))

	var lo:= Vector3(INF, INF, INF)
	var hi:= - lo
	var found:= false
	for node: Node in nodes:
		for vis: VisualInstance3D in _visuals(node):
			var mi:= vis as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var xf:= mi.global_transform
			for surface in mi.mesh.get_surface_count():
				var arrays:= mi.mesh.surface_get_arrays(surface)
				if arrays.size() <= Mesh.ARRAY_VERTEX:
					continue
				var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]


				var step:= maxi(1, verts.size() / 3000)
				var i:= 0
				while i < verts.size():
					var p: Vector3 = xf * verts [i]
					if (p - centre).dot(dir) >= cut:
						lo = lo.min(p)
						hi = hi.max(p)
						found = true
					i += step
	if not found:
		return whole
	return AABB(lo, hi - lo)


func _aabb_of(nodes: Array) -> AABB:
	var lo:= Vector3(INF, INF, INF)
	var hi:= Vector3(- INF, - INF, - INF)
	var any:= false
	for node: Node in nodes:
		for vis: VisualInstance3D in _visuals(node):
			var local:= vis.get_aabb()
			if local.size.length() <= 0.0:
				continue
			var xf:= vis.global_transform
			for i in 8:
				var p: Vector3 = xf * (local.position + local.size * Vector3(
					float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1)))
				lo = lo.min(p)
				hi = hi.max(p)
				any = true
	if not any:
		return AABB()
	return AABB(lo, hi - lo)


func _hush(nodes: Array) -> void:
	for node: Node in nodes:
		if node == null:
			continue
		var stack: Array [Node] = [node]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is GPUParticles3D:
				var fx:= n as GPUParticles3D
				fx.emitting = false
				fx.visible = false
			for child in n.get_children():
				stack.append(child)


func _visuals(node: Node) -> Array [VisualInstance3D]:
	var out: Array [VisualInstance3D] = []
	var stack: Array [Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var named:= str(n.name)
		var skipped:= false
		for bad: String in SKIP_NAMES:
			if named.begins_with(bad):
				skipped = true
				break
		if skipped:
			continue
		if n is Node3D and not (n as Node3D).visible:
			continue


		if n is VisualInstance3D and not (n is GPUParticles3D) and not (n is Light3D) and not (n is Decal):
			out.append(n as VisualInstance3D)
		for child in n.get_children():
			stack.append(child)
	return out


func _capture(path: String) -> void:


	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img:= _view.get_texture().get_image()
	img.save_png(path)


func _contact_sheet(out_dir: String) -> void:
	var names: Array [String] = []
	for spec: Dictionary in SUBJECTS:
		var id:= str(spec ["id"])
		if FileAccess.file_exists("%s/%s.png" % [out_dir, id]):
			names.append(id)
	if names.is_empty():
		return
	var side:= 192
	var cols:= SHEET_COLS
	var rows:= int(ceil(float(names.size()) / float(cols)))
	var sheet:= Image.create_empty(cols * side, rows * side, false,
		Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.085, 0.1, 1.0))
	for i in names.size():
		var img:= Image.load_from_file("%s/%s.png" % [out_dir, names [i]])
		if img == null:
			continue
		img.resize(side, side, Image.INTERPOLATE_LANCZOS)
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(0, 0, side, side),
			Vector2i((i % cols) * side, (i / cols) * side))
	sheet.save_png("%s/_contact.png" % out_dir)


func _build(id: String) -> Array:
	var builds = world.get("builds")
	var props = world.get("props")
	match id:
		"spade", "pitchfork", "broom", "toy_shovel", "metal_detector", "yard_vac", "lighter":
			var item_id:= "sand_shovel" if id == "toy_shovel" else id
			return [_prop(props, item_id, _stage)]
		"bucket":
			return [_prop(props, "bucket", _stage)]
		"bucket_full":
			var b:= _prop(props, "bucket", _stage) as HayContainer
			return [_fill_container(b)]
		"bucket_pour":
			return [await _bucket_pouring(props)]
		"wheelbarrow":
			return [_prop(props, "wheelbarrow", _stage)]
		"wheelbarrow_full":
			var w:= _prop(props, "wheelbarrow", _stage) as HayContainer
			return [_fill_container(w)]
		"hay_wad":
			return [_prop(props, "hay_wad", _stage)]
		"hay_bale":
			return [_prop(props, "hay_bale", _stage)]


		"foiled_bale":
			return [_prop(props, "foiled_bale", _stage)]
		"eco_brick":
			return [_prop(props, "eco_brick", _stage)]
		"strand":
			return [_strand()]
		"needle":
			return [_needle()]
		"hay_pulp", "paper_roll", "feed_disc":
			return [_prop(props, id, _stage)]

		"platform":
			return [builds.add_platform(_stage + Vector3(0, 1.6, 0), Vector2(3.0, 3.0))]
		"railing":
			return [builds.add_railing(_stage + Vector3(-1.6, 0, 0),
				_stage + Vector3(1.6, 0, 0))]
		"stairs":
			return [_stair_flight(builds)]
		"wall":
			return [builds.add_wall(_stage + Vector3(0, 0, -2.0),
				_stage + Vector3(0, 0, 2.0), YardWall.Bay.SOLID)]
		"wall_window":
			return [builds.add_wall(_stage + Vector3(0, 0, -2.0),
				_stage + Vector3(0, 0, 2.0), YardWall.Bay.WINDOW)]


		"wall_door":
			return [builds.add_wall(_stage + Vector3(0, 0, -1.0),
				_stage + Vector3(0, 0, 1.0), YardWall.Bay.DOOR)]


		"roof":
			return [builds.add_roof(_stage + Vector3(0, 0, -2.0),
				_stage + Vector3(0, 0, 2.0), Roof.Kind.FLAT, 1)]


		"roof_pitch":
			return [builds.add_roof(_stage + Vector3(0, 0, -2.0),
				_stage + Vector3(0, 0, 2.0), Roof.Kind.PITCHED, 1, 2)]


		"roof_hatch":
			var landing = builds.add_platform(_stage,
				Vector2(Cfg.PLATFORM_TILE, Cfg.PLATFORM_TILE))


			for i in 2:
				await get_tree().physics_frame
			var hatch = builds.add_roof(
				_stage + Vector3(0.0, Cfg.WALL_HEIGHT, -1.0),
				_stage + Vector3(0.0, Cfg.WALL_HEIGHT, 1.0), Roof.Kind.HATCH, 1)
			for i in 2:
				await get_tree().physics_frame


			hatch.refresh_ladder(true)
			await get_tree().process_frame
			return [hatch, landing]
		"beam":
			return [_loose_mesh(StructureKit.beam_mesh(),
				StructureKit.beam_material(), 1.0)]
		"beam_stack":
			return _beam_stack()

		"belt":
			return [builds.add_conveyor(_stage + Vector3(-1.3, 0, 0),
				_stage + Vector3(1.3, 0, 0))]
		"belt_loaded":
			return await _belt_loaded(builds, props)
		"enclosed_belt":
			builds.add_enclosed_conveyor(_stage + Vector3(-2.0, 0, 0),
				_stage + Vector3(2.0, 0, 0))
			await get_tree().process_frame
			var shell: Node3D = builds._enclosed_visuals
			if shell == null:
				return []
			var door:= shell.get_node_or_null("Outlet_0/DoorAnimation") as AnimationPlayer
			if door != null and door.has_animation("Open"):
				door.play("Open")
				door.seek(door.get_animation("Open").length, true)
				door.pause()
			return [shell]
		"splitter":
			return await _wye(builds.add_splitter(_stage, 0.0), false)
		"joiner":
			return await _wye(builds.add_joiner(_stage, 0.0), true)


		"u_splitter":
			return await _wye(builds.add_u_splitter(_stage, 0.0), false)
		"u_joiner":
			return await _wye(builds.add_u_joiner(_stage, 0.0), true)


		"t_splitter":
			return await _wye(builds.add_t_splitter(_stage, PI), false)


		"compact_splitter":
			return [builds.add_compact_splitter(_stage, 0.0, false)]
		"smart_splitter":
			return [builds.add_compact_splitter(_stage, 0.0, true)]
		"compressor":
			return [builds.add_compressor(_stage, 0.0)]
		"wrapper":


			return [_wrapper_posed(builds)]
		"silo":


			var tank: HaySilo = builds.add_silo(_stage, 0.0)
			tank.pose_for_shot()
			return [tank]
		"pelletizer":
			return [builds.add_pelletizer(_stage, 0.0)]
		"pulper":


			var pulper: HayPulper = builds.add_pulper(_stage, 0.0)
			await _wait(0.2)
			pulper._run = Cfg.PULPER_CYCLE_SECONDS * 0.42
			pulper._apply_charge()
			pulper._apply_pour()
			pulper._apply_lamp()
			var clip:= HayPulper._clip_name(pulper._door, HayPulper.CLIP_DOOR)
			if clip != "":
				pulper._door.play(clip)
				pulper._door.seek(Cfg.PULPER_CYCLE_SECONDS * 0.42, true)
				pulper._door.pause()


			pulper.set_water_blocked(false)
			await _wait(0.2)
			return [pulper]
		"briquette_press":


			var briq: BriquettePress = builds.add_briquette(
				Vector3(_stage.x, 0.0, _stage.z), 0.0)
			await _wait(0.2)
			briq.pose_for_shot()
			await _wait(0.2)
			return [briq]
		"paper_machine":


			var paper: PaperMachine = builds.add_paper(_stage, 0.0)
			await _wait(0.2)
			paper.pose_for_shot()
			await _wait(0.2)
			return [paper]
		"generator":


			var gen: HayGenerator = builds.add_generator(_stage, 0.0)
			gen.fuel = gen.capacity()
			await _wait(0.3)
			return [gen]
		"gas_plant":


			var plant: GasPlant = builds.add_gas_plant(_stage, 0.0)
			plant.fuel = plant.capacity()
			await _wait(2.5)
			var rig: Node = plant._model
			if rig != null and "drive" in rig:
				rig.set("drive", 1.0)
				rig.set("speed", 1.0)
				rig.set("heat", 1.0)
			return [plant]
		"borehole":


			var pump: BoreholePump = builds.add_borehole(_stage, 0.0)
			await _wait(0.1)
			if pump._anim != null and pump._clip_name() != "":
				pump._anim.play(pump._clip_name())
				pump._anim.seek(pump.clip_seconds() * 0.25, true)
				pump._anim.pause()
			return [pump]
		"water_main":


			var run: WaterMain = builds.add_water_main(
				_stage + Vector3(-1.5, Cfg.PIPE_RUN_HEIGHT, 0.0),
				_stage + Vector3(1.5, Cfg.PIPE_RUN_HEIGHT, 0.0))


			run.set_flow(1.0)
			await _wait(0.3)
			return [run]
		"water_splitter":


			return [builds.add_water_splitter(
				_stage + Vector3(0.0, Cfg.PIPE_RUN_HEIGHT, 0.0), 0.0)]
		"power_pole":
			return [builds.add_power_pole(_stage, 0.0)]
		"power_box":


			return [builds.add_power_pole(_stage, 0.0, true)]
		"dump_hatch":


			return [builds.add_dump_hatch(_stage, 0.0)]
		"tube_launcher":


			return [builds.add_tube_launcher(_stage, 0.0)]
		"hay_stairs":
			return [builds.add_hay_stairs(_stage, 0.0)]
		"hay_lift":


			return [builds.add_hay_lift(
				_stage + Vector3(0.0, Cfg.HAY_LIFT_DECK, 0.0), 0.0, 3)]
		"piston_rake":
			return [builds.add_piston_rake(_stage, 0.0)]

		"arm":
			return [builds.add_robotic_arm(_stage, 0.0, 0)]
		"arm_long":
			return [builds.add_robotic_arm(_stage, 0.0,
				Cfg.ROBOT_ARM_TIERS.size() - 1)]
		"arm_carry":
			return await _arm_carrying(builds, props)
		"drone":
			return [builds.add_hay_drone(_stage, 0.0)]

		"scanner":
			return [builds.add_scanner(_stage, 0.0)]
		"cabinet":
			return [builds.add_cabinet(_stage, 0.0)]
		"needle_radar":
			var dish: NeedleRadar = builds.add_needle_radar(_stage, 0.0)
			await _wait(0.1)


			dish.set_process(false)
			dish.pose(80.0, 38.0)
			return [dish]
		"cabinet_open":
			var cab = builds.add_cabinet(_stage, 0.0)
			await _wait(0.1)
			if cab.has_method("open_doors"):
				cab.open_doors()
			await _wait(1.2)
			return [cab]

		"paintboard":
			var board: PaintBoard = builds.add_paint_board(_stage, 0.0)
			await _wait(0.1)
			board.rotate_secs = 0
			board.set_picture(_board_scrawl())


			await _wait(0.3)
			return [board]

		"work_lamp":
			var lamp: WorkLamp = builds.add_work_lamp(_stage, 0.0)
			await _wait(0.2)
			return [lamp]

		"selling_stand":
			return [_fixture(HaySellingStand.new())]
		"shop":
			return [_fixture(HayShop.new())]
		"door":
			return [_fixture(BayDoor.new())]

		"boots", "gloves", "tape_measure", "step_ladder", "feathers", "winged_shoe", "anvil", "water_bottle", "dumbbell":
			return [_downloaded(id)]
		"pitchfork_swing":
			return [_prop(props, "pitchfork", _stage)]
		"boots_hay":
			return await _boots_in_hay()

		"warehouse":
			return await _shed(Warehouse.INNER)
		"warehouse_wide":
			return await _shed(Warehouse.INNER + 18.0)
	return []


func _board_scrawl() -> Array:
	var ink:= PaintBoard.SWATCHES [0]
	var w: float = PaintBoard.WIDTHS [3]
	var ring:= PackedVector2Array([Vector2(0.22, 0.16), Vector2(0.78, 0.84)])
	var eyes:= PackedVector2Array([Vector2(0.38, 0.38), Vector2(0.44, 0.46)])
	var eyes2:= PackedVector2Array([Vector2(0.56, 0.38), Vector2(0.62, 0.46)])
	var grin:= PackedVector2Array([Vector2(0.34, 0.58), Vector2(0.42, 0.7),
		Vector2(0.58, 0.7), Vector2(0.66, 0.58)])
	return [
		{ "t": int(PaintBoard.Tool.ELLIPSE), "c": ink, "w": w, "p": ring },
		{ "t": int(PaintBoard.Tool.ELLIPSE), "c": ink, "w": w, "p": eyes },
		{ "t": int(PaintBoard.Tool.ELLIPSE), "c": ink, "w": w, "p": eyes2 },
		{ "t": int(PaintBoard.Tool.PEN), "c": ink, "w": w, "p": grin },
	]


func _shed(inner: float) -> Array:
	var shed:= Warehouse.new()
	shed.follow_tech = false
	shed.inner = inner
	shed.set_door_void(Warehouse.Wall.X_POS, 0.0,
		BayDoor.OPENING_W, BayDoor.OPENING_H)
	world.add_child(shed)
	shed.global_position = _stage
	_live.append(shed)


	var door:= BayDoor.new()
	door.warehouse = shed
	door.wall = BayDoor.Wall.X_POS
	door.along = 0.0
	shed.add_child(door)


	await _wait(0.4)
	_strip_apron(shed)
	return [shed]


func _strip_apron(shed: Node3D) -> void:
	for child in shed.get_children():
		if child is YardGround:
			shed.remove_child(child)
			child.queue_free()
			return


func _downloaded(id: String) -> Node3D:
	var packed: PackedScene = load(str(DOWNLOADED [id]))
	if packed == null:
		push_warning("[iconshots] %s did not load" % id)
		return null
	var n:= packed.instantiate() as Node3D
	for name: String in DOWNLOADED_DROP.get(id, []):
		var spare:= n.find_child(name, true, false)
		if spare != null:
			spare.get_parent().remove_child(spare)
			spare.queue_free()
	world.add_child(n)
	n.global_position = _stage
	_live.append(n)
	return n


func _boots_in_hay() -> Array:
	var boots:= _downloaded("boots")
	if boots == null:
		return []
	var live = world.get("live")
	if live == null:
		return [boots]


	await get_tree().process_frame
	var feet:= _aabb_of([boots])
	var sole:= Vector3(feet.get_center().x, feet.position.y, feet.get_center().z)


	var rng:= RandomNumberGenerator.new()
	rng.seed = 23
	for i in HAY_STRANDS:
		var a:= rng.randf() * TAU
		var r:= sqrt(rng.randf()) * HAY_SCATTER
		var at:= sole + Vector3(cos(a) * r, 0.1 + rng.randf() * 0.05, sin(a) * r)
		var spin:= Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf() * TAU)
		live.spawn(at, spin, Vector3.ZERO, StrandFactory.random_tint(rng))
	await _wait(0.9)
	_pad = AABB(sole - Vector3(HAY_SCATTER, 0.0, HAY_SCATTER),
		Vector3(HAY_SCATTER * 2.0, 0.02, HAY_SCATTER * 2.0))
	return [boots]


func _beam_stack() -> Array:
	var mesh:= StructureKit.beam_mesh()
	var mat:= StructureKit.beam_material()
	var one:= mesh.get_aabb()

	var lift:= one.size.y * 1.08
	var pitch:= one.size.x * 1.25
	var out: Array = []
	for layer in STACK_LAYERS:
		var turned:= layer % 2 == 1
		for i in STACK_ACROSS:
			var across:= (float(i) - float(STACK_ACROSS - 1) * 0.5) * pitch
			var at:= Vector3(across, lift * float(layer), 0.0) if not turned else Vector3(0.0, lift * float(layer), across)
			var mi:= MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			world.add_child(mi)
			var turn:= Basis(Vector3.UP, PI * 0.5) if turned else Basis()
			mi.global_transform = Transform3D(turn, _stage + at)
			_live.append(mi)
			out.append(mi)
	return out


func _prop(props, item_id: String, at: Vector3) -> Node3D:
	var item: Carryable = props.spawn(item_id, Transform3D(Basis(), at))
	if item == null:
		return null
	item.freeze = true
	_live.append(item)
	return item


func _fill_container(c: HayContainer) -> Node3D:
	if c == null:
		return null
	c.stored = c.capacity()
	if c.has_method("_refresh_fill"):
		c.call("_refresh_fill")
	return c


func _bucket_pouring(props) -> Node3D:


	Tech.grant("smooth_pour", 3)
	var at:= _stage + Vector3(0.0, POUR_HEIGHT, 0.0)
	var b:= _prop(props, "bucket", at) as Bucket
	if b == null:
		return null
	b.stored = b.capacity()
	if b.has_method("_refresh_fill"):
		b.call("_refresh_fill")
	var screen:= _screen_basis()
	var dir:= (screen.x * -1.0 + screen.z * 0.25).normalized()
	b.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), at)
	await _wait(POUR_TIME)


	_pad = AABB(at, Vector3.ZERO)
	_pad = _pad.expand(at + dir * 0.3 + Vector3(0.0, - POUR_HEIGHT, 0.0))
	_pad = _pad.expand(at - dir * 0.22 + Vector3.UP * 0.16)
	return b


func _belt_loaded(builds, props) -> Array:


	var belt = builds.add_conveyor(_stage + Vector3(-1.3, 0, 0),
		_stage + Vector3(1.3, 0, 0))
	var out: Array = [belt]
	await get_tree().process_frame
	var deck: float = (belt.a as Vector3).y
	for i in 3:
		var at:= _stage + Vector3(-0.8 + 0.8 * float(i), deck, 0.0)
		var wad:= _prop(props, "hay_wad", at)
		if wad == null:
			continue
		await get_tree().process_frame
		var box:= _aabb_of([wad])
		if box.size.y > 0.0:
			wad.global_position = at + Vector3(0.0, at.y - box.position.y, 0.0)
		out.append(wad)
	return out


func _wrapper_posed(builds) -> Node3D:
	var wrap: HayWrapper = builds.add_wrapper(_stage, 0.0)


	wrap.pose_for_shot()
	return wrap


func _wye(module, inward: bool) -> Array:
	var out: Array = [module]
	if module == null:
		return out
	await get_tree().process_frame
	var centre: Vector3 = module.global_position
	var builds = world.get("builds")


	var odd: Vector3 = module.port_out() if module.has_method("port_out") else module.port_in()
	for mouth: Vector3 in (module.ports() as Array):
		var dir: Vector3 = mouth - centre
		dir.y = 0.0
		if dir.length_squared() <= 1e-06:
			continue


		if module is ConveyorUSplitter or module is ConveyorUJoiner:
			var along: Vector3 = module.forward()
			dir = along if dir.dot(along) > 0.0 else - along
		var far: Vector3 = mouth + dir.normalized() * STUB
		var feeds_in: bool = inward
		if mouth.is_equal_approx(odd):
			feeds_in = not inward
		if feeds_in:
			out.append(builds.add_conveyor(far, mouth))
		else:
			out.append(builds.add_conveyor(mouth, far))
	await get_tree().process_frame
	return out


func _arm_carrying(builds, props) -> Array:
	var arm = builds.add_robotic_arm(_stage, 0.0, 1)
	var out: Array = [arm]
	await _wait(0.4)
	var centre:= Vector3.ZERO
	var found:= 0
	for i in 8:
		var pivot:= (arm as Node).find_child("RA_ClawPivot_%d" % i, true, false) as Node3D
		if pivot == null:
			continue
		centre += pivot.global_position
		found += 1
	if found == 0:
		push_warning("[iconshots] arm_carry: no claw pivots -- arm shot bare")
		return out
	if arm.has_method("_apply_claw"):
		arm.call("_apply_claw", RoboticArm.CLAW_CLOSED)
	var wad:= _prop(props, "hay_wad",
		centre / float(found) + Vector3(0.0, -0.12, 0.0))
	if wad != null:
		out.append(wad)
	return out


func _stair_flight(builds) -> Node3D:
	var across:= _screen_basis().x
	across.y = 0.0
	across = across.normalized()
	var yaw:= atan2(- across.x, - across.z)
	var rise:= 1.4
	return builds.add_stair(_stage + Vector3(0.0, rise, 0.0), yaw, rise)


func _loose_mesh(mesh: Mesh, mat: Material, scale: float) -> Node3D:
	var mi:= MeshInstance3D.new()
	mi.mesh = mesh
	if mat != null:
		mi.material_override = mat
	world.add_child(mi)
	mi.global_transform = Transform3D(Basis().scaled(Vector3.ONE * scale), _stage)
	_live.append(mi)
	return mi


func _strand() -> Node3D:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = StrandFactory.strand_mesh()
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D())


	var rng:= RandomNumberGenerator.new()
	rng.seed = 7
	mm.set_instance_color(0, StrandFactory.random_tint(rng))
	var mmi:= MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = StrandFactory.hay_material()
	world.add_child(mmi)
	mmi.global_transform = Transform3D(Basis().scaled(Vector3.ONE * 6.0), _stage)
	_live.append(mmi)
	return mmi


func _needle() -> Node3D:
	var mi:= MeshInstance3D.new()
	mi.mesh = StrandFactory.needle_model()
	var mats:= StrandFactory.needle_surface_materials()
	for i in mats.size():
		mi.set_surface_override_material(i, mats [i])
	world.add_child(mi)
	mi.global_transform = Transform3D(Basis().scaled(Vector3.ONE * 4.0), _stage)
	_live.append(mi)
	return mi


func _fixture(node: Node3D) -> Node3D:
	if "live" in node:
		node.set("live", world.get("live"))
	if "props" in node:
		node.set("props", world.get("props"))
	world.add_child(node)
	node.global_position = _stage
	_live.append(node)
	return node


func _clear() -> void:
	_pad = AABB()
	for node: Node in _live:
		if is_instance_valid(node) and node.get_parent() == world:
			world.remove_child(node)
			node.queue_free()
	_live.clear()
	var builds = world.get("builds")
	if builds != null:
		builds.clear()
	var props = world.get("props")
	if props != null:
		props.clear()
