class_name DebugView
extends Node3D


enum Bodies { OFF, SOLID, ALL }

const SOLID_LAYERS:= Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP | Cfg.L_PLAYER | Cfg.L_TOOL


const MAX_SHAPES:= 1600


const RESCAN:= 0.6


const C_STRAND:= Color(0.42, 0.92, 0.45)
const C_PROP:= Color(1.0, 0.68, 0.25)
const C_PLAYER:= Color(0.4, 0.72, 1.0)
const C_OTHER:= Color(0.92, 0.42, 0.9)

const C_WORLD:= Color(0.62, 0.66, 0.72)
const C_PILE:= Color(0.78, 0.62, 0.34)
const C_BUILD:= Color(0.35, 0.88, 0.94)
const C_TOOL:= Color(0.86, 0.86, 0.42)

const ZONE_FILL_A:= 0.13
const LABEL_SIZE:= 0.28

var zones:= false
var bodies: int = Bodies.OFF

var _zone_root: Node3D
var _body_root: Node3D


var _tracked: Array [Dictionary] = []
var _rescan_in:= 0.0
var _truncated:= 0


func _ready() -> void:
	_zone_root = Node3D.new()
	_zone_root.name = "Zones"
	add_child(_zone_root)
	_body_root = Node3D.new()
	_body_root.name = "Bodies"
	add_child(_body_root)
	set_process(false)


func set_zones(on: bool) -> int:
	zones = on
	_rebuild()
	return _zone_root.get_child_count()


func set_bodies(mode: int) -> Array [int]:
	bodies = mode
	_rebuild()
	return [_body_root.get_child_count(), _truncated]


func is_idle() -> bool:
	return not zones and bodies == Bodies.OFF


func _process(delta: float) -> void:


	var live: Array [Dictionary] = []
	for entry in _tracked:


		var src = entry ["src"]
		var vis = entry ["vis"]
		if not is_instance_valid(src) or not is_instance_valid(vis):
			if is_instance_valid(vis):
				(vis as Node3D).queue_free()
			continue
		(vis as Node3D).global_transform = (src as Node3D).global_transform
		live.append(entry)
	_tracked = live

	_rescan_in -= delta
	if _rescan_in <= 0.0:
		_rebuild()


func _rebuild() -> void:
	_rescan_in = RESCAN
	_truncated = 0
	_tracked.clear()
	for child in _zone_root.get_children():
		child.queue_free()
	for child in _body_root.get_children():
		child.queue_free()

	if is_idle():
		set_process(false)
		return
	set_process(true)

	var drawn:= 0
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()

		if node == self:
			continue
		for kid in node.get_children():
			stack.append(kid)
		if drawn >= MAX_SHAPES:
			_truncated += 1
			continue
		if node is CollisionShape3D:
			if _draw_shape(node as CollisionShape3D):
				drawn += 1


func _draw_shape(cs: CollisionShape3D) -> bool:
	var shape:= cs.shape
	if shape == null or cs.disabled:
		return false
	var owner_body:= cs.get_parent()
	var is_zone:= owner_body is Area3D
	if is_zone:
		if not zones:
			return false
		var mask: int = (owner_body as Area3D).collision_mask
		_add_zone(cs, shape, _zone_colour(mask), String(owner_body.name))
		return true

	if bodies == Bodies.OFF or not (owner_body is CollisionObject3D):
		return false
	var layer: int = (owner_body as CollisionObject3D).collision_layer
	if bodies == Bodies.SOLID and (layer & SOLID_LAYERS) == 0:
		return false
	_add_wire(_body_root, cs, shape, _body_colour(layer))
	return true


func _add_zone(cs: CollisionShape3D, shape: Shape3D, colour: Color,
		label: String) -> void:
	var holder:= _add_wire(_zone_root, cs, shape, colour)

	var solid:= _solid_mesh(shape)
	if solid != null:
		var fill:= MeshInstance3D.new()
		fill.mesh = solid
		var mat:= StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(colour.r, colour.g, colour.b, ZONE_FILL_A)
		fill.material_override = mat
		fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(fill)

	var text:= Label3D.new()
	text.text = label
	text.font_size = 48
	text.pixel_size = LABEL_SIZE / 48.0
	text.modulate = colour
	text.outline_modulate = Color(0, 0, 0, 0.85)
	text.outline_size = 10
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.no_depth_test = true
	text.position = Vector3.UP * (_half_height(shape) + 0.18)
	holder.add_child(text)


func _add_wire(root: Node3D, cs: CollisionShape3D, shape: Shape3D,
		colour: Color) -> Node3D:
	var holder:= Node3D.new()
	holder.top_level = true
	holder.name = String(cs.name)
	root.add_child(holder)
	holder.global_transform = cs.global_transform

	var wire:= MeshInstance3D.new()


	wire.mesh = shape.get_debug_mesh()
	var mat:= StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(colour.r, colour.g, colour.b, 0.85)
	mat.no_depth_test = true
	wire.material_override = mat
	wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(wire)

	_tracked.append({ "src": cs, "vis": holder })
	return holder


func _solid_mesh(shape: Shape3D) -> Mesh:
	if shape is BoxShape3D:
		var box:= BoxMesh.new()
		box.size = (shape as BoxShape3D).size
		return box
	if shape is SphereShape3D:
		var ball:= SphereMesh.new()
		ball.radius = (shape as SphereShape3D).radius
		ball.height = ball.radius * 2.0
		return ball
	if shape is CylinderShape3D:
		var cyl:= CylinderMesh.new()
		cyl.top_radius = (shape as CylinderShape3D).radius
		cyl.bottom_radius = cyl.top_radius
		cyl.height = (shape as CylinderShape3D).height
		return cyl
	if shape is CapsuleShape3D:
		var cap:= CapsuleMesh.new()
		cap.radius = (shape as CapsuleShape3D).radius
		cap.height = (shape as CapsuleShape3D).height
		return cap
	return null


func _half_height(shape: Shape3D) -> float:
	var mesh:= shape.get_debug_mesh()
	if mesh == null:
		return 0.5
	var aabb:= mesh.get_aabb()
	return aabb.position.y + aabb.size.y


func _zone_colour(mask: int) -> Color:
	if (mask & Cfg.L_STRAND) != 0:
		return C_STRAND
	if (mask & Cfg.L_PROP) != 0:
		return C_PROP
	if (mask & Cfg.L_PLAYER) != 0:
		return C_PLAYER
	return C_OTHER


func _body_colour(layer: int) -> Color:
	if (layer & Cfg.L_PILE) != 0:
		return C_PILE
	if (layer & Cfg.L_STRAND) != 0:
		return C_STRAND
	if (layer & Cfg.L_BUILD) != 0:
		return C_BUILD
	if (layer & Cfg.L_PROP) != 0:
		return C_PROP
	if (layer & Cfg.L_PLAYER) != 0:
		return C_PLAYER
	if (layer & Cfg.L_TOOL) != 0:
		return C_TOOL
	return C_WORLD
