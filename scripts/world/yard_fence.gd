class_name YardFence
extends Node3D


signal gate_settled(open: bool)

const MODEL:= "res://assets/models/Fence/compiled/modular_chainlink_fence_2k.scn"
const TEX:= "res://assets/models/Fence/textures/modular_chainlink_fence_%s_2k.%s"

const PANEL_NODE:= "modular_chainlink_fence_double"
const POST_NODE:= "modular_chainlink_fence_post"


const BAY:= 2.0


const PANEL_LOW:= 0.06
const PANEL_HIGH:= 2.43


const POST_TALL:= 2.52


const HANGER_THICK:= 1.7
const HANGER_TALL:= 2.72


const FRAME_THICK:= 0.4


const LEAF_GAP:= 0.04


const HEIGHT:= 2.5


const PEN_HEIGHT:= 2000.0


const PEN_THICK:= 1.0


const PEN_FOOT:= 4.0


const SHED_GAP:= 0.5


const THICK:= 0.16


const MARGIN:= 0.7


const WEAVE_TILE:= 3.0


const SWING_TIME:= 2.6


const SWING:= PI * 0.5


const OPEN_DISTANCE:= 5.0
const AIM_SLACK:= 0.25


var wall_x0:= -17.5
var wall_x1:= 17.5


var shed_depth:= 35.0


var reach_out:= 22.0
var reach_half:= 16.0


const OVERLAP:= 0.6


const SLACK:= 1.5


var gate_w:= 7.2


var corridor_half:= 5.7
var corridor_out:= 56.0


var fog_from:= 30.0


var ground_y:= 0.0

var _mat_posts: StandardMaterial3D
var _mat_wire: StandardMaterial3D


var _leaves: Array [Node3D] = []
var _shut_yaw: Array [float] = []
var _open_yaw: Array [float] = []


var _swing:= 0.0
var _want:= 0.0


func _ready() -> void:
	set_process(false)


func build() -> void:
	var kit: PackedScene = load(MODEL)
	if kit == null:
		push_warning("YardFence: no fence kit at %s, the yard is open" % MODEL)
		return
	var src:= kit.instantiate()
	var panel:= src.get_node_or_null(NodePath(PANEL_NODE)) as MeshInstance3D
	var post:= src.get_node_or_null(NodePath(POST_NODE)) as MeshInstance3D
	if panel == null or post == null:
		push_warning("YardFence: the fence kit has no '%s'/'%s' in it"
			% [PANEL_NODE, POST_NODE])
		src.free()
		return

	_build_materials()


	var panel_mesh:= _dressed(panel.mesh)
	var post_mesh:= _dressed(post.mesh)
	var panel_basis:= panel.transform.basis
	var post_basis:= post.transform.basis

	var posts: Array [Transform3D] = []
	var panels: Array [Transform3D] = []


	var line:= { }
	var body:= StaticBody3D.new()
	body.name = "FenceCollision"
	body.collision_layer = Cfg.L_WORLD
	body.collision_mask = 0
	add_child(body)


	var pen:= StaticBody3D.new()
	pen.name = "PenCollision"
	pen.collision_layer = Cfg.L_PEN
	pen.collision_mask = 0
	add_child(pen)

	for run: PackedVector2Array in _runs():
		_run(run [0], run [1], panel_basis, panels, line, body, pen)

	_ring(pen)


	var g:= gate_w * 0.5
	for at: Vector2 in [Vector2(- g, reach_out), Vector2(g, reach_out),
			Vector2(- g, corridor_out), Vector2(g, corridor_out)]:
		line.erase(_key(at))
	_gate(Vector2(- g, reach_out), Vector2(g, reach_out), panel_mesh, post_mesh,
		panel_basis, post_basis, posts, true)
	_gate(Vector2(- g, corridor_out), Vector2(g, corridor_out), panel_mesh, post_mesh,
		panel_basis, post_basis, posts, false)
	for at: Vector2 in line.values():
		posts.append(Transform3D(post_basis, _at(at)))

	_scatter(self, panel_mesh, panels, "FencePanels")
	_scatter(self, post_mesh, posts, "FencePosts")
	_build_fog()


	src.free()
	_apply_swing()


func _runs() -> Array [PackedVector2Array]:
	var x0:= _side_x(-1.0)
	var x1:= _side_x(1.0)
	var g:= gate_w * 0.5
	var c:= corridor_half
	var out:= reach_out
	var far:= corridor_out
	return [
		PackedVector2Array([Vector2(wall_x0, 0.0), Vector2(x0, 0.0)]),
		PackedVector2Array([Vector2(x0, 0.0), Vector2(x0, out)]),
		PackedVector2Array([Vector2(x0, out), Vector2(- g, out)]),
		PackedVector2Array([Vector2(g, out), Vector2(x1, out)]),
		PackedVector2Array([Vector2(x1, out), Vector2(x1, 0.0)]),
		PackedVector2Array([Vector2(x1, 0.0), Vector2(wall_x1, 0.0)]),
		PackedVector2Array([Vector2(- c, out), Vector2(- c, far)]),
		PackedVector2Array([Vector2(c, out), Vector2(c, far)]),
		PackedVector2Array([Vector2(- c, far), Vector2(- g, far)]),
		PackedVector2Array([Vector2(g, far), Vector2(c, far)]),
	]


func _side_x(sign: float) -> float:
	if sign < 0.0:
		return minf(wall_x0, - reach_half) - MARGIN
	return maxf(wall_x1, reach_half) + MARGIN


func _shed_x(sign: float) -> float:
	return wall_x0 - SHED_GAP if sign < 0.0 else wall_x1 + SHED_GAP


func _ring_outline() -> PackedVector2Array:
	var sx0:= _shed_x(-1.0)
	var sx1:= _shed_x(1.0)
	var back:= - shed_depth - SHED_GAP
	var x0:= _side_x(-1.0)
	var x1:= _side_x(1.0)
	var loop:= PackedVector2Array()
	for c: Vector2 in [Vector2(sx0, back), Vector2(sx0, 0.0), Vector2(x0, 0.0),
			Vector2(x0, reach_out), Vector2(x1, reach_out), Vector2(x1, 0.0),
			Vector2(sx1, 0.0), Vector2(sx1, back)]:
		if loop.is_empty() or loop [loop.size() - 1].distance_to(c) > 0.01:
			loop.append(c)
	return loop


func _ring(pen: StaticBody3D) -> void:
	var loop:= _ring_outline()
	var n:= loop.size()
	for i in n:
		var a:= loop [i]
		var b:= loop [(i + 1) % n]
		var length:= a.distance_to(b)
		var dir:= (b - a) / length
		var outward:= Vector2(dir.y, - dir.x)
		if _in_plan((a + b) * 0.5 + outward * 0.05, 0.0):
			outward = - outward
		var run_back:= PEN_THICK if _outside_corner(loop [(i + n - 1) % n], a, b) else 0.0
		var run_on:= PEN_THICK if _outside_corner(a, b, loop [(i + 2) % n]) else 0.0
		var box:= BoxShape3D.new()
		box.size = Vector3(length + run_back + run_on, PEN_HEIGHT + PEN_FOOT, PEN_THICK)
		var cs:= CollisionShape3D.new()
		cs.name = "Ring%d" % i
		cs.shape = box
		var at:= (a + b) * 0.5 + dir * ((run_on - run_back) * 0.5) + outward * (PEN_THICK * 0.5)
		cs.transform = Transform3D(Basis(Vector3.UP, _yaw(dir)),
			Vector3(at.x, ground_y + (PEN_HEIGHT - PEN_FOOT) * 0.5, at.y))
		pen.add_child(cs)


func _outside_corner(from: Vector2, at: Vector2, to: Vector2) -> bool:
	var probe:= at + (from - at).normalized() * 0.05 + (to - at).normalized() * 0.05
	return _in_plan(probe, 0.0)


func encloses(point: Vector3) -> bool:
	var p:= to_local(point)
	return _in_plan(Vector2(p.x, p.z), SLACK)


func _in_plan(p: Vector2, slack: float) -> bool:
	var apron:= (p.x >= _side_x(-1.0) - slack and p.x <= _side_x(1.0) + slack
		and p.y >= - slack and p.y <= reach_out + slack)
	var shed:= (p.x >= _shed_x(-1.0) - slack and p.x <= _shed_x(1.0) + slack
		and p.y >= - shed_depth - SHED_GAP - slack and p.y <= slack)
	return apron or shed


func _at(p: Vector2) -> Vector3:
	return Vector3(p.x, ground_y, p.y)


func _key(p: Vector2) -> String:
	return "%.2f,%.2f" % [p.x, p.y]


func _yaw(dir: Vector2) -> float:
	return atan2(- dir.y, dir.x)


func _run(a: Vector2, b: Vector2, panel_basis: Basis,
		panels: Array [Transform3D], line: Dictionary, body: StaticBody3D,
		pen: StaticBody3D) -> void:
	var span:= b - a
	var length:= span.length()
	if length < 0.05:
		return
	var dir:= span / length
	var turn:= Basis(Vector3.UP, _yaw(dir))
	var bays:= maxi(1, roundi(length / BAY))
	var step:= length / bays
	for i in bays + 1:
		var post_at:= a + dir * (step * i)
		line [_key(post_at)] = post_at
	for i in bays:
		var panel_at:= a + dir * (step * (i + 1))
		panels.append(Transform3D(
			turn * panel_basis.scaled_local(Vector3(step / BAY, 1.0, 1.0)),
			_at(panel_at)))


	var shape:= BoxShape3D.new()
	shape.size = Vector3(length, HEIGHT, THICK)
	var cs:= CollisionShape3D.new()
	cs.shape = shape
	var mid:= (a + b) * 0.5
	cs.transform = Transform3D(turn, Vector3(mid.x, ground_y + HEIGHT * 0.5, mid.y))
	body.add_child(cs)


	var tall:= BoxShape3D.new()
	tall.size = Vector3(length + OVERLAP * 2.0, PEN_HEIGHT, THICK)
	var tcs:= CollisionShape3D.new()
	tcs.shape = tall
	tcs.transform = Transform3D(turn,
		Vector3(mid.x, ground_y + PEN_HEIGHT * 0.5, mid.y))
	pen.add_child(tcs)


func _gate(a: Vector2, b: Vector2, panel_mesh: Mesh, post_mesh: Mesh,
		panel_basis: Basis, post_basis: Basis, posts: Array [Transform3D],
		swings: bool) -> void:
	var span:= b - a
	var width:= span.length()
	if width < 1.0:
		return
	var dir:= span / width


	for at: Vector2 in [a, b]:
		posts.append(Transform3D(post_basis.scaled_local(
			Vector3(HANGER_THICK, HANGER_THICK, HANGER_TALL / POST_TALL)), _at(at)))


	var half:= (width - LEAF_GAP) * 0.5
	var near:= _leaf(a, dir, half, panel_mesh, post_mesh, panel_basis, post_basis)
	var away:= _leaf(b, - dir, half, panel_mesh, post_mesh, panel_basis, post_basis)


	_pen_wall(a, b)
	if not swings:
		return


	_leaves = [near, away]
	_shut_yaw = [near.rotation.y, away.rotation.y]
	_open_yaw = [near.rotation.y - SWING, away.rotation.y + SWING]


func _pen_wall(a: Vector2, b: Vector2) -> void:
	var span:= b - a
	var width:= span.length()
	var body:= StaticBody3D.new()
	body.name = "GateBlock"
	body.collision_layer = Cfg.L_PEN
	body.collision_mask = 0
	var shape:= BoxShape3D.new()
	shape.size = Vector3(width + OVERLAP * 2.0, PEN_HEIGHT, THICK)
	var cs:= CollisionShape3D.new()
	cs.shape = shape
	cs.position = _at((a + b) * 0.5) + Vector3.UP * (PEN_HEIGHT * 0.5)
	cs.rotation.y = _yaw(span / width)
	body.add_child(cs)
	add_child(body)


func _leaf(hinge: Vector2, dir: Vector2, width: float, panel_mesh: Mesh,
		post_mesh: Mesh, panel_basis: Basis, post_basis: Basis) -> Node3D:
	var leaf:= Node3D.new()
	leaf.name = "Leaf"
	leaf.position = _at(hinge)
	leaf.rotation.y = _yaw(dir)
	add_child(leaf)


	var panels: Array [Transform3D] = []
	var bay:= width * 0.5
	for i in 2:
		panels.append(Transform3D(panel_basis.scaled_local(Vector3(bay / BAY, 1.0, 1.0)),
			Vector3(bay * (i + 1), 0.0, 0.0)))


	var tubes: Array [Transform3D] = []
	for x: float in [0.0, width * 0.5, width]:
		tubes.append(_tube(Vector3(x, PANEL_LOW, 0.0), Vector3(x, PANEL_HIGH, 0.0),
			post_basis))
	for y: float in [PANEL_LOW, PANEL_HIGH]:
		tubes.append(_tube(Vector3(0.0, y, 0.0), Vector3(width, y, 0.0), post_basis))
	tubes.append(_tube(Vector3(0.0, PANEL_LOW, 0.0), Vector3(width, PANEL_HIGH, 0.0),
		post_basis))

	_scatter(leaf, panel_mesh, panels, "Wire")
	_scatter(leaf, post_mesh, tubes, "Frame")


	var body:= AnimatableBody3D.new()
	body.name = "LeafCollision"
	body.sync_to_physics = false
	body.collision_layer = Cfg.L_WORLD
	body.collision_mask = 0


	var shape:= BoxShape3D.new()
	shape.size = Vector3(width + LEAF_GAP, HEIGHT, THICK)
	var cs:= CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3((width + LEAF_GAP) * 0.5, HEIGHT * 0.5, 0.0)
	body.add_child(cs)
	leaf.add_child(body)
	return leaf


func _tube(from: Vector3, to: Vector3, post_basis: Basis) -> Transform3D:
	var span:= to - from
	var length:= span.length()
	var dir:= span / length
	var size:= Basis.from_scale(Vector3(FRAME_THICK, length / POST_TALL, FRAME_THICK))

	var lean:= Basis.IDENTITY
	var axis:= Vector3.UP.cross(dir)
	if axis.length() > 0.0001:
		lean = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	return Transform3D(lean * size * post_basis, from)


func gate_point() -> Vector3:
	return to_global(Vector3(0.0, ground_y + 1.2, reach_out))


func is_hovered(eye: Vector3, look: Vector3) -> bool:
	if _leaves.is_empty():
		return false
	if eye.distance_to(gate_point()) > OPEN_DISTANCE:
		return false


	var from:= to_local(eye)
	var dir:= to_local(eye + look.normalized()) - from
	if absf(dir.z) < 0.0001:
		return false
	var t:= (reach_out - from.z) / dir.z
	if t <= 0.0:
		return false
	var hit:= from + dir * t
	return absf(hit.x) <= gate_w * 0.5 + AIM_SLACK and hit.y >= ground_y - AIM_SLACK and hit.y <= ground_y + HEIGHT + AIM_SLACK


func is_open() -> bool:
	return _want > 0.5


func is_shut() -> bool:
	return _want < 0.5 and is_equal_approx(_swing, 0.0)


func set_open(open: bool) -> void:
	var want:= 1.0 if open else 0.0
	if is_equal_approx(_want, want):
		return
	_want = want
	set_process(true)


	Audio.play_3d("truck_gate_up", gate_point(), -4.0)


func toggle() -> bool:
	if _leaves.is_empty():
		return false
	return true


func _process(delta: float) -> void:
	var was:= _swing
	_swing = move_toward(_swing, _want, delta / SWING_TIME)
	if is_equal_approx(_swing, was):
		return
	_apply_swing()
	if is_equal_approx(_swing, _want):
		set_process(false)
		gate_settled.emit(is_open())


func _apply_swing() -> void:
	var t:= smoothstep(0.0, 1.0, _swing)
	for i in _leaves.size():
		_leaves [i].rotation.y = lerp_angle(_shut_yaw [i], _open_yaw [i], t)


func _build_fog() -> void:
	var depth:= corridor_out - fog_from
	if depth < 1.0:
		return
	var fog:= FogVolume.new()
	fog.name = "CorridorFog"
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fog.size = Vector3(corridor_half * 2.0, 9.0, depth)
	fog.position = Vector3(0.0, ground_y + 4.5, (fog_from + corridor_out) * 0.5)
	var mat:= FogMaterial.new()
	mat.density = 0.22
	mat.albedo = Color(0.84, 0.86, 0.88)


	mat.edge_fade = 0.35
	fog.material = mat
	add_child(fog)


func _scatter(parent: Node, mesh: Mesh, xforms: Array [Transform3D],
		node_name: String) -> void:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms [i])
	var mmi:= MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	parent.add_child(mmi)


func _dressed(src: Mesh) -> Mesh:
	var mesh: Mesh = src.duplicate()
	for i in mesh.get_surface_count():
		var was:= mesh.surface_get_material(i)
		var is_wire:= was != null and was.resource_name.ends_with("wire")
		mesh.surface_set_material(i, _mat_wire if is_wire else _mat_posts)
	return mesh


func _build_materials() -> void:
	_mat_posts = _kit_material("posts", "png")
	_mat_wire = _kit_material("wire", "webp")


	_mat_wire.uv1_scale = Vector3(WEAVE_TILE, WEAVE_TILE, 1.0)
	_mat_wire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_mat_wire.alpha_scissor_threshold = 0.5
	_mat_wire.cull_mode = BaseMaterial3D.CULL_DISABLED


func _kit_material(part: String, albedo_ext: String) -> StandardMaterial3D:
	var m:= StandardMaterial3D.new()


	var albedo_map:= "%s_ab" % part if albedo_ext == "webp" else "%s_diff" % part
	m.albedo_texture = load(TEX % [albedo_map, albedo_ext])
	var nrm: Texture2D = load(TEX % ["%s_nor_gl" % part, "png"])
	if nrm != null:
		m.normal_enabled = true
		m.normal_texture = nrm
	var rgh: Texture2D = load(TEX % ["%s_rough" % part, "png"])
	if rgh != null:
		m.roughness_texture = rgh
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED


	var mtl: Texture2D = load(TEX % ["%s_metal" % part, "png"])
	if mtl != null:
		m.metallic = 1.0
		m.metallic_texture = mtl
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	return m
