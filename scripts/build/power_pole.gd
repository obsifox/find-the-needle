class_name PowerPole
extends Node3D


const MODEL:= "res://assets/models/compiled/power_pole.scn"
const SPEC:= "res://assets/models/power_pole_materials.json"

const N_WIRE:= "Marker_Wire"
const N_GROUND:= "Marker_Ground"


const WIRE_FALLBACK:= Vector3(0.0, 3.206, -0.011)

static var _spec_cache: Dictionary = { }

static var _skins: Dictionary = { }


const DECK_CUT:= Cfg.PLATFORM_PLATE_THICK * 0.5


static var _cut_cache: Dictionary = { }


var placement_preview:= false


var gift:= false

var _model: Node3D = null
var _anchors: Array [Node3D] = []


var on_deck:= false


var _whole: Dictionary = { }


var links_to: Array [PowerPole] = []
var links_at: Array [Vector3] = []


var _wires: Array [Node3D] = []


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_load_model()
	_skin()
	if on_deck:
		_fit_to_floor()
	_find_anchors()
	_setup_bodies()
	if placement_preview:
		set_preview_valid(true)
		return
	add_to_group("power_poles")


func _load_model() -> void:
	var scene: PackedScene = load(model_path()) as PackedScene
	if scene == null:
		push_warning("PowerPole: no model at %s" % model_path())
		return
	_model = scene.instantiate() as Node3D
	add_child(_model)


func model_path() -> String:
	return MODEL


func spec_path() -> String:
	return SPEC


func wire_fallback() -> Vector3:
	return WIRE_FALLBACK


func wire_anchors() -> Array [Node3D]:
	if _anchors.is_empty():
		_find_anchors()
	return _anchors


func wire_point() -> Vector3:
	var list:= wire_anchors()
	return (to_global(wire_fallback()) if list.is_empty()
		else list [0].global_position)


func connect_to(other: Node3D, settled: bool = false) -> PowerLine:
	if other == null:
		return null
	var kept:= _reclaim(PowerLine.anchors_of(self), PowerLine.anchors_of(other))
	if kept != null:
		return kept
	var line:= PowerLine.hang(self, self, other, _wire_material(), settled)
	if line != null:
		_wires.append(line)
	return line


func connect_anchor(anchor: Node3D, settled: bool = false) -> PowerLine:
	if anchor == null or not is_instance_valid(anchor):
		return null
	var list:= wire_anchors()
	if list.is_empty():
		return null
	var from: Array [Node3D] = [list [0]]
	var to: Array [Node3D] = [anchor]
	var kept:= _reclaim(from, to)
	if kept != null:
		return kept
	var line:= PowerLine.hang_at(self, list [0], anchor, _wire_material(), settled)
	if line != null:
		_wires.append(line)
	return line


var _old_wires: Array [Node3D] = []


static var _wire_mats: Dictionary = { }


func _wire_material() -> Material:
	var key:= spec_path()
	if not _wire_mats.has(key):
		_wire_mats [key] = HayCompressor.make_material(PowerLine.WIRE_MAT, spec_table(),
			load(HayCompressor.SHADER) as Shader)
	return _wire_mats [key]


func begin_restring() -> void:
	end_restring()
	for line in _wires:
		if is_instance_valid(line):
			_old_wires.append(line)
	_wires.clear()


func end_restring() -> void:
	for line in _old_wires:
		if is_instance_valid(line):
			remove_child(line)
			line.queue_free()
	_old_wires.clear()


func _reclaim(from: Array [Node3D], to: Array [Node3D]) -> PowerLine:
	for i in _old_wires.size():
		var line:= _old_wires [i] as PowerLine
		if line == null or not is_instance_valid(line):
			continue
		if line.from_anchors == from and line.to_anchors == to:
			_old_wires.remove_at(i)
			_wires.append(line)
			return line
	return null


func clear_wires() -> void:
	for line in _wires:
		if is_instance_valid(line):
			remove_child(line)
			line.queue_free()
	_wires.clear()


func wire_count() -> int:
	return _wires.size()


func wires() -> Array [PowerLine]:
	var out: Array [PowerLine] = []
	for node in _wires:
		if node is PowerLine and is_instance_valid(node):
			out.append(node as PowerLine)
	return out


func traces() -> Array [CableTrace]:
	var out: Array [CableTrace] = []
	for node in _wires:
		if node is CableTrace and is_instance_valid(node):
			out.append(node as CableTrace)
	return out


func buried() -> bool:
	return false


func link_reach() -> float:
	return Tech.pole_link_r()


func supply_reach() -> float:
	return Tech.pole_supply_r()


func footprint() -> Vector2:
	return Vector2(0.2, 0.2)


func own_bodies() -> Array [RID]:

	return PowerGrid.own_bodies(self)


func _setup_bodies() -> void:
	for node in find_children("*", "StaticBody3D", true, false):
		var body:= node as StaticBody3D
		if body == null:
			continue
		body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
		body.collision_mask = 0
		for child in body.get_children():
			var col:= child as CollisionShape3D
			if col != null and col.shape is ConcavePolygonShape3D:
				col.shape = _solid(col.shape as ConcavePolygonShape3D)
	if placement_preview:
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static var _solids: Dictionary = { }


static func _solid(skin: ConcavePolygonShape3D) -> ConvexPolygonShape3D:
	if not _solids.has(skin):
		var hull:= ConvexPolygonShape3D.new()
		hull.points = skin.get_faces()
		_solids [skin] = hull
	return _solids [skin]


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


func set_on_deck(value: bool) -> void:
	if value == on_deck:
		return
	on_deck = value
	if _model != null:
		_fit_to_floor()


func _fit_to_floor() -> void:
	for mesh in _meshes():
		if not on_deck:
			if _whole.has(mesh):
				_swap_mesh(mesh, _whole [mesh])
			continue
		if _whole.has(mesh) or mesh.mesh == null:
			continue
		var cut:= _cut_mesh(mesh.mesh, _to_post(mesh), - DECK_CUT)
		if cut != mesh.mesh:
			_whole [mesh] = mesh.mesh
			_swap_mesh(mesh, cut)
	if not on_deck:
		_whole.clear()


func _to_post(node: Node3D) -> Transform3D:
	var xf:= node.transform
	var up:= node.get_parent()
	while up != null and up != self:
		if up is Node3D:
			xf = (up as Node3D).transform * xf
		up = up.get_parent()
	return xf


static func _swap_mesh(instance: MeshInstance3D, mesh: Mesh) -> void:
	var skins: Array [Material] = []
	for i in instance.get_surface_override_material_count():
		skins.append(instance.get_surface_override_material(i))
	instance.mesh = mesh
	for i in mini(skins.size(), instance.get_surface_override_material_count()):
		instance.set_surface_override_material(i, skins [i])


static func _cut_mesh(mesh: Mesh, xf: Transform3D, cut: float) -> Mesh:
	var key:= "%d %s %.4f" % [mesh.get_instance_id(), xf, cut]
	if _cut_cache.has(key):
		return _cut_cache [key]
	var src:= mesh as ArrayMesh
	var reaches:= (xf * mesh.get_aabb()).position.y < cut


	var surfaces: Array [Array] = []
	if src != null and reaches:
		for s in src.get_surface_count():
			var arrays:= src.surface_get_arrays(s)
			if src.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES or arrays.size() != Mesh.ARRAY_MAX or arrays [Mesh.ARRAY_VERTEX] == null:
				reaches = false
				break
			surfaces.append(arrays)
	if src == null or not reaches:
		_cut_cache [key] = mesh
		return mesh
	var out:= ArrayMesh.new()
	out.resource_name = src.resource_name
	for s in surfaces.size():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
			_cut_surface(surfaces [s], xf, cut))
		out.surface_set_name(s, src.surface_get_name(s))
		out.surface_set_material(s, src.surface_get_material(s))
	_cut_cache [key] = out
	return out


static func _cut_surface(arrays: Array, xf: Transform3D, cut: float) -> Array:
	var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
	var normals:= PackedVector3Array()
	if arrays [Mesh.ARRAY_NORMAL] != null:
		normals = arrays [Mesh.ARRAY_NORMAL]
	var tangents:= PackedFloat32Array()
	if arrays [Mesh.ARRAY_TANGENT] != null:
		tangents = arrays [Mesh.ARRAY_TANGENT]
	var colors:= PackedColorArray()
	if arrays [Mesh.ARRAY_COLOR] != null:
		colors = arrays [Mesh.ARRAY_COLOR]
	var uv:= PackedVector2Array()
	if arrays [Mesh.ARRAY_TEX_UV] != null:
		uv = arrays [Mesh.ARRAY_TEX_UV]
	var uv2:= PackedVector2Array()
	if arrays [Mesh.ARRAY_TEX_UV2] != null:
		uv2 = arrays [Mesh.ARRAY_TEX_UV2]
	var index:= PackedInt32Array()
	if arrays [Mesh.ARRAY_INDEX] != null:
		index = arrays [Mesh.ARRAY_INDEX]
	else:
		index.resize(verts.size())
		for i in verts.size():
			index [i] = i

	var h:= PackedFloat32Array()
	h.resize(verts.size())
	for i in verts.size():
		h [i] = (xf * verts [i]).y

	var kept:= PackedInt32Array()


	var splits: Dictionary = { }
	for f in range(0, index.size() - 2, 3):
		var tri: Array [int] = [index [f], index [f + 1], index [f + 2]]
		var below:= 0
		for v in tri:
			if h [v] < cut:
				below += 1
		if below == 3:
			continue
		if below == 0:
			kept.append(tri [0])
			kept.append(tri [1])
			kept.append(tri [2])
			continue

		var poly: Array [int] = []
		for e in 3:
			var a: int = tri [e]
			var b: int = tri [(e + 1) % 3]
			var a_in:= h [a] >= cut
			if a_in:
				poly.append(a)
			if a_in == (h [b] >= cut):
				continue
			var edge:= Vector2i(mini(a, b), maxi(a, b))
			if not splits.has(edge):
				var lo:= edge.x
				var hi:= edge.y
				var t:= (cut - h [lo]) / (h [hi] - h [lo])
				splits [edge] = verts.size()
				verts.append(verts [lo].lerp(verts [hi], t))
				h.append(cut)
				if not normals.is_empty():
					normals.append(normals [lo].lerp(normals [hi], t).normalized())
				if not tangents.is_empty():
					var ta:= Vector3(tangents [lo * 4], tangents [lo * 4 + 1], tangents [lo * 4 + 2])
					var tb:= Vector3(tangents [hi * 4], tangents [hi * 4 + 1], tangents [hi * 4 + 2])
					var tn:= ta.lerp(tb, t).normalized()
					tangents.append(tn.x)
					tangents.append(tn.y)
					tangents.append(tn.z)
					tangents.append(tangents [lo * 4 + 3])
				if not colors.is_empty():
					colors.append(colors [lo].lerp(colors [hi], t))
				if not uv.is_empty():
					uv.append(uv [lo].lerp(uv [hi], t))
				if not uv2.is_empty():
					uv2.append(uv2 [lo].lerp(uv2 [hi], t))
			poly.append(int(splits [edge]))
		for k in range(1, poly.size() - 1):
			kept.append(poly [0])
			kept.append(poly [k])
			kept.append(poly [k + 1])


	if kept.is_empty():
		kept = PackedInt32Array([0, 0, 0])

	var out:= []
	out.resize(Mesh.ARRAY_MAX)
	out [Mesh.ARRAY_VERTEX] = verts
	if not normals.is_empty():
		out [Mesh.ARRAY_NORMAL] = normals
	if not tangents.is_empty():
		out [Mesh.ARRAY_TANGENT] = tangents
	if not colors.is_empty():
		out [Mesh.ARRAY_COLOR] = colors
	if not uv.is_empty():
		out [Mesh.ARRAY_TEX_UV] = uv
	if not uv2.is_empty():
		out [Mesh.ARRAY_TEX_UV2] = uv2
	out [Mesh.ARRAY_INDEX] = kept
	return out


func build_cost() -> float:
	return 0.0 if gift else Cfg.POLE_COST


func to_dict() -> Dictionary:
	var d:= {
		"type": "power_pole",
		"position": global_position,
		"yaw": global_rotation.y,
	}
	if gift:
		d ["gift"] = true
	var at: Array [Vector3] = []
	for other in links_to:
		if is_instance_valid(other):
			at.append(other.global_position)
	if at.is_empty():
		at = links_at.duplicate()
	if not at.is_empty():
		d ["links"] = at
	return d


func link(others: Array [PowerPole]) -> void:
	links_to.clear()
	links_at.clear()
	for other in others:
		if is_instance_valid(other):
			links_to.append(other)
			links_at.append(other.global_position)


func add_links(others: Array [PowerPole]) -> void:
	for other in others:
		if other == self or not is_instance_valid(other) or links_to.has(other):
			continue


		if other.strung_to(self):
			continue
		links_to.append(other)
		links_at.append(other.global_position)


func unlink(other: PowerPole) -> void:
	var at:= links_to.find(other)
	if at < 0:
		return
	links_to.remove_at(at)
	if at < links_at.size():
		links_at.remove_at(at)


func strung_to(other: PowerPole) -> bool:
	return links_to.has(other)


func _find_anchors() -> void:
	_anchors.clear()
	var node:= _find(N_WIRE) as Node3D
	if node == null:


		var stand_in:= Node3D.new()
		stand_in.name = N_WIRE
		stand_in.position = wire_fallback()
		add_child(stand_in)
		node = stand_in
	_anchors.append(node)


func _find(node_name: String) -> Node:
	if _model == null:
		return null
	return _model.find_child(node_name, true, false)


func _skin() -> void:
	if _model == null:
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("PowerPole: no material table at %s, the model will render untextured" % spec_path())
		return
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = _skins.get(spec_path(), { })
	_skins [spec_path()] = built
	var missed: Dictionary = { }
	for mesh in _meshes():
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null:
				continue
			var key:= src.resource_name
			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = HayCompressor.make_material(key, spec, shader)
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
	if not missed.is_empty():
		push_warning("PowerPole: no table entry for %s" % ", ".join(missed.keys()))


func _meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if _model == null:
		return out
	var stack: Array [Node] = [_model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			out.append(node as MeshInstance3D)
		for child in node.get_children():
			stack.append(child)
	return out


func spec_table() -> Dictionary:
	return spec_table_at(spec_path())


static func spec_table_at(path: String) -> Dictionary:
	if _spec_cache.has(path):
		return _spec_cache [path]
	var table: Dictionary = { }


	var res: JSON = load(path) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		table = res.data
	elif FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			table = parsed
	if not table.is_empty():
		_spec_cache [path] = table
	return table
