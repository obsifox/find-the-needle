class_name DevPlazaProbe
extends Node


const OUT_DEFAULT:= "user://plaza"


const KEEP:= ["HayField", "BrutalistPlaza"]


const SHOTS:= [


	{ "file": "plaza_colossus.png", "dir": Vector3(0.2, 0.0, 1.0),
		"h": 1.7, "out": 34.0, "aim_y": 44.0,
		"note": "at the foot of it, looking up" },
	{ "file": "plaza_pile.png", "dir": Vector3(-0.55, 0.0, 0.84),
		"h": 1.7, "out": 52.0, "aim_y": 26.0,
		"note": "eye height, pile in frame for scale" },
	{ "file": "plaza_wide.png", "dir": Vector3(0.3, 0.0, 1.0),
		"h": 22.0, "out": 230.0, "aim_y": 40.0,
		"note": "back far enough to hold the massing" },
]


const PILE_CLEAR:= 19.0

var world: Node3D
var player: Player

var _scale:= BrutalistPlaza.SCALE


var _bounds:= AABB()
var _blocks: Array [AABB] = []


var _names: Array [String] = []


func shoot(out_dir: String, scale_factor: float) -> void:


	world.block_save = true
	_scale = scale_factor
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	_stand_up_the_plaza()
	_strip_the_yard()
	_hide_the_hud()

	await get_tree().process_frame
	await get_tree().process_frame

	for shot: Dictionary in SHOTS:
		await _look(out_dir, shot)
	get_tree().quit(0)


func _stand_up_the_plaza() -> void:
	var plaza: BrutalistPlaza = world.get("plaza")
	if plaza != null and is_equal_approx(_scale, BrutalistPlaza.SCALE):
		_measure(plaza)
		_report()
		return

	if plaza != null:
		plaza.queue_free()
		world.remove_child(plaza)
	plaza = BrutalistPlaza.new()
	plaza.name = "BrutalistPlaza"
	world.add_child(plaza)
	plaza.build(_scale)
	world.set("plaza", plaza)
	_measure(plaza)
	print("plaza: %d masses at scale %.2f (tallest %.0f m above the apron)"
		% [_blocks.size(), _scale, _bounds.end.y])


func _report() -> void:
	var tallest:= 0.0
	var name:= ""
	for i in _blocks.size():
		if _blocks [i].end.y > tallest:
			tallest = _blocks [i].end.y
			name = _names [i]
	print("plaza: %.0f x %.0f m footprint, %.0f m tall (%s), scale %.2f"
		% [_bounds.size.x, _bounds.size.z, tallest, name, _scale])
	print("plaza: %.0f storeys at 3 m, and the pile beside it is 30 m across"
		% (tallest / 3.0))


func _measure(plaza: BrutalistPlaza) -> void:


	for mi: MeshInstance3D in plaza.masses():
		if mi.name == "Apron":
			continue
		var world_aabb: AABB = mi.global_transform * mi.get_aabb()
		_blocks.append(world_aabb)
		_names.append(String(mi.name))
		_bounds = world_aabb if _blocks.size() == 1 else _bounds.merge(world_aabb)


func _strip_the_yard() -> void:
	var hidden: Array [String] = []
	for child: Node in world.get_children():
		if child == player or String(child.name) in KEEP:
			continue
		if child is DirectionalLight3D or child is WorldEnvironment or child is Camera3D:
			continue
		if child is Node3D:
			(child as Node3D).visible = false
			hidden.append(String(child.name))
	print("plaza: hid %d yard nodes" % hidden.size())


	var lit:= 0
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Light3D and node.get_parent() != world:
			(node as Light3D).visible = false
			lit += 1
		for kid: Node in node.get_children():
			stack.append(kid)
	print("plaza: hid %d lights that are not the sun" % lit)


func _hide_the_hud() -> void:
	var n:= 0
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false
			n += 1
			continue
		for child: Node in node.get_children():
			stack.append(child)
	print("plaza: hid %d canvas layers" % n)


func _look(out_dir: String, shot: Dictionary) -> void:
	var dir: Vector3 = (shot ["dir"] as Vector3).normalized()


	var eye:= dir * maxf(float(shot ["out"]), PILE_CLEAR)
	eye.y = float(shot ["h"])
	var at:= Vector3(0.0, float(shot ["aim_y"]), 0.0)
	eye = _clear_of_masses(eye, dir)

	player.global_position = eye
	player.look_at_from_position(eye, at, Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:


		var to:= at - eye
		player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [out_dir, shot ["file"]])
	print("wrote %-16s at (%.0f, %.0f, %.0f)  (%s)"
		% [shot ["file"], eye.x, eye.y, eye.z, shot ["note"]])


func _clear_of_masses(eye: Vector3, dir: Vector3) -> Vector3:
	const AIR:= 1.0
	const STEP:= 4.0
	const GIVE_UP:= 400
	var at:= eye
	for _i: int in GIVE_UP:
		var hit:= false
		for b: AABB in _blocks:
			if b.grow(AIR).has_point(at):
				hit = true
				break
		if not hit:
			return at
		at += dir * STEP * maxf(_scale, 0.05)
	push_warning("DevPlazaProbe: could not find open ground along %v" % dir)
	return at
