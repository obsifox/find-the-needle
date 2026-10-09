class_name StructureKit
extends RefCounted


const LEG_SECTION:= 0.15
const FOOT_SIZE:= 0.42
const FOOT_THICK:= 0.045

const BEAM_WIDTH:= 0.11
const RAIL_POST_SECTION:= 0.06
const RAIL_SECTION:= 0.055


const WALL_SOURCE:= "res://assets/models/compiled/wall.scn"

static var _deck: ArrayMesh
static var _beam: ArrayMesh
static var _leg: ArrayMesh
static var _foot: ArrayMesh
static var _rail_post: ArrayMesh
static var _rail: ArrayMesh
static var _tread: ArrayMesh
static var _stringer: ArrayMesh
static var _wall_panel: ArrayMesh
static var _wall_window: ArrayMesh
static var _wall_door: ArrayMesh
static var _wall_post: ArrayMesh
static var _wall_loaded:= false

static var _roof_sheet: Array [ArrayMesh] = [null, null]
static var _roof_rafter: Array [ArrayMesh] = [null, null]


static var _hatch_side: Array [ArrayMesh] = [null, null]
static var _hatch_end: Array [ArrayMesh] = [null, null]
static var _ladder_stile: ArrayMesh
static var _ladder_rung: ArrayMesh
static var _plate_mat: ShaderMaterial
static var _beam_mat: ShaderMaterial
static var _sheet_mat: ShaderMaterial


static func deck_mesh() -> ArrayMesh:
	if _deck == null:
		_deck = _box(Vector3(Cfg.PLATFORM_TILE, Cfg.PLATFORM_PLATE_THICK,
			Cfg.PLATFORM_TILE), Vector3(0.0, - Cfg.PLATFORM_PLATE_THICK * 0.5, 0.0))
		_deck.surface_set_material(0, plate_material())
	return _deck


static func beam_mesh() -> ArrayMesh:
	if _beam == null:
		var depth:= Cfg.PLATFORM_THICK - Cfg.PLATFORM_PLATE_THICK
		_beam = _box(Vector3(BEAM_WIDTH, depth, Cfg.PLATFORM_TILE),
			Vector3(0.0, - Cfg.PLATFORM_PLATE_THICK - depth * 0.5, 0.0))
		_beam.surface_set_material(0, beam_material())
	return _beam


static func leg_mesh() -> ArrayMesh:
	if _leg == null:
		_leg = _box(Vector3(LEG_SECTION, 1.0, LEG_SECTION), Vector3(0.0, -0.5, 0.0))
		_leg.surface_set_material(0, beam_material())
	return _leg


static func foot_mesh() -> ArrayMesh:
	if _foot == null:
		_foot = _box(Vector3(FOOT_SIZE, FOOT_THICK, FOOT_SIZE),
			Vector3(0.0, FOOT_THICK * 0.5, 0.0))
		_foot.surface_set_material(0, beam_material())
	return _foot


static func rail_post_mesh() -> ArrayMesh:
	if _rail_post == null:
		_rail_post = _box(
			Vector3(RAIL_POST_SECTION, Cfg.PLATFORM_RAIL_H, RAIL_POST_SECTION),
			Vector3(0.0, Cfg.PLATFORM_RAIL_H * 0.5, 0.0))
		_rail_post.surface_set_material(0, beam_material())
	return _rail_post


static func rail_mesh() -> ArrayMesh:
	if _rail == null:
		_rail = _box(Vector3(RAIL_SECTION, RAIL_SECTION, 1.0), Vector3.ZERO)
		_rail.surface_set_material(0, beam_material())
	return _rail


const TREAD_GOING:= Cfg.STAIR_RISER / Cfg.STAIR_PITCH


static func tread_mesh() -> ArrayMesh:
	if _tread == null:
		_tread = _box(
			Vector3(Cfg.STAIR_WIDTH, Cfg.PLATFORM_PLATE_THICK, TREAD_GOING),
			Vector3(0.0, - Cfg.PLATFORM_PLATE_THICK * 0.5, 0.0))
		_tread.surface_set_material(0, plate_material())
	return _tread


static func stringer_mesh() -> ArrayMesh:
	if _stringer == null:
		_stringer = _box(Vector3(BEAM_WIDTH, Cfg.PLATFORM_THICK, 1.0), Vector3.ZERO)
		_stringer.surface_set_material(0, beam_material())
	return _stringer


static func roof_run(pitched: bool) -> float:
	if not pitched:
		return Cfg.ROOF_DEPTH
	return sqrt(Cfg.ROOF_DEPTH * Cfg.ROOF_DEPTH + Cfg.ROOF_RISE * Cfg.ROOF_RISE)


static func roof_pitch() -> float:
	return atan2(Cfg.ROOF_RISE, Cfg.ROOF_DEPTH)


static func roof_sheet_mesh(pitched: bool) -> ArrayMesh:
	var slot:= 1 if pitched else 0
	if _roof_sheet [slot] == null:
		_roof_sheet [slot] = _box(
			Vector3(roof_run(pitched), Cfg.ROOF_SHEET_THICK, Cfg.ROOF_BAY),
			Vector3(0.0, - Cfg.ROOF_SHEET_THICK * 0.5, 0.0))
		_roof_sheet [slot].surface_set_material(0, sheet_material())
	return _roof_sheet [slot]


static func roof_hatch_side_mesh(deck:= false) -> ArrayMesh:
	var slot:= 1 if deck else 0
	if _hatch_side [slot] == null:
		_hatch_side [slot] = _hatch_strip(Vector3(roof_hatch_margin(), 0.0,
			Cfg.ROOF_BAY), deck)
	return _hatch_side [slot]


static func roof_hatch_end_mesh(deck:= false) -> ArrayMesh:
	var slot:= 1 if deck else 0
	if _hatch_end [slot] == null:
		_hatch_end [slot] = _hatch_strip(Vector3(Cfg.ROOF_HATCH, 0.0,
			roof_hatch_margin()), deck)
	return _hatch_end [slot]


static func _hatch_strip(size: Vector3, deck: bool) -> ArrayMesh:
	size.y = Cfg.PLATFORM_PLATE_THICK if deck else Cfg.ROOF_SHEET_THICK
	var mesh:= _box(size, Vector3(0.0, - size.y * 0.5, 0.0))
	mesh.surface_set_material(0, plate_material() if deck else sheet_material())
	return mesh


static func roof_hatch_margin() -> float:
	return (Cfg.ROOF_DEPTH - Cfg.ROOF_HATCH) * 0.5


static func roof_rafter_mesh(pitched: bool) -> ArrayMesh:
	var slot:= 1 if pitched else 0
	if _roof_rafter [slot] == null:
		var depth:= Cfg.PLATFORM_THICK - Cfg.ROOF_SHEET_THICK
		_roof_rafter [slot] = _box(
			Vector3(roof_run(pitched), depth, BEAM_WIDTH),
			Vector3(0.0, - Cfg.ROOF_SHEET_THICK - depth * 0.5, 0.0))
		_roof_rafter [slot].surface_set_material(0, beam_material())
	return _roof_rafter [slot]


static func ladder_stile_mesh() -> ArrayMesh:
	if _ladder_stile == null:
		_ladder_stile = _box(Vector3(Cfg.LADDER_STILE, 1.0, Cfg.LADDER_STILE),
			Vector3(0.0, -0.5, 0.0))
		_ladder_stile.surface_set_material(0, beam_material())
	return _ladder_stile


static func ladder_rung_mesh() -> ArrayMesh:
	if _ladder_rung == null:
		_ladder_rung = _box(
			Vector3(Cfg.LADDER_WIDTH, Cfg.LADDER_RUNG, Cfg.LADDER_RUNG),
			Vector3.ZERO)
		_ladder_rung.surface_set_material(0, beam_material())
	return _ladder_rung


static func wall_panel_mesh(kind: int) -> ArrayMesh:
	_load_wall()
	match kind:
		YardWall.Bay.WINDOW:
			return _wall_window
		YardWall.Bay.DOOR:
			return _wall_door
	return _wall_panel


static func wall_post_mesh() -> ArrayMesh:
	_load_wall()
	return _wall_post


static func _load_wall() -> void:
	if _wall_loaded:
		return
	_wall_loaded = true
	var packed: PackedScene = load(WALL_SOURCE)
	if packed == null:
		push_error("StructureKit: cannot load %s: run "
			% WALL_SOURCE + "`blender -b -P assets/blender/_build/wall.py`")
		return
	var root:= packed.instantiate()
	_wall_panel = _wall_mesh_of(root, "WallPanel")
	_wall_window = _wall_mesh_of(root, "WallWindow")
	_wall_door = _wall_mesh_of(root, "WallDoor")
	_wall_post = _wall_mesh_of(root, "WallPost")
	root.free()

	_dress_wall(_wall_panel, 2)
	_dress_wall(_wall_window, 2)
	_dress_wall(_wall_door, 2)
	_dress_wall(_wall_post, 1)


static func _wall_mesh_of(root: Node, node_name: String) -> ArrayMesh:
	var mi:= root.find_child(node_name, true, false) as MeshInstance3D
	if mi == null:
		push_error("StructureKit: %s has no MeshInstance3D '%s'"
			% [WALL_SOURCE, node_name])
		return null


	return mi.mesh as ArrayMesh


static func _dress_wall(mesh: ArrayMesh, expect: int) -> void:
	if mesh == null:
		return
	var n:= mesh.get_surface_count()
	if n != expect:
		push_error("StructureKit: expected %d surfaces on a wall part, got %d: "
			% [expect, n] + "the materials in assets/blender/_build/wall.py no "
			+ "longer split it")
		return
	for i in n:
		var old:= mesh.surface_get_material(i)
		var id:= old.resource_name if old != null else ""
		if id.contains("Plate"):
			mesh.surface_set_material(i, plate_material())
			continue
		if not id.contains("Beam"):
			push_warning("StructureKit: unrecognised wall surface '%s', painting "
				% id + "as frame")
		mesh.surface_set_material(i, beam_material())


static func plate_material() -> ShaderMaterial:
	if _plate_mat == null:
		_plate_mat = _pbr("blue_metal_plate", 2.0, Cfg.COL_DECK_PLATE, 0.22,
			0.52, 0.88, 0.0, 1.4)
	return _plate_mat


static func beam_material() -> ShaderMaterial:
	if _beam_mat == null:
		_beam_mat = _pbr("rusty_metal_03", 1.0, Cfg.COL_DECK_BEAM, 0.34,
			0.58, 0.9, 0.0, 1.0)
	return _beam_mat


static func sheet_material() -> ShaderMaterial:
	if _sheet_mat == null:
		_sheet_mat = _pbr("worn_corrugated_iron", 1.0, Cfg.COL_ROOF_SHEET, 0.3,
			0.44, 0.82, 0.0, 1.8)
	return _sheet_mat


static func _pbr(asset: String, per_metre: float, tint: Color, saturation: float,
		rough_min: float, rough_max: float, metallic: float,
		normal_depth: float) -> ShaderMaterial:
	var m:= ShaderMaterial.new()
	m.shader = load(ConveyorKit.SHADER)
	m.set_shader_parameter("tex_per_metre", per_metre)


	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("saturation", saturation)
	m.set_shader_parameter("rough_min", rough_min)
	m.set_shader_parameter("rough_max", rough_max)
	m.set_shader_parameter("metallic", metallic)
	m.set_shader_parameter("normal_depth", normal_depth)


	m.set_shader_parameter("speed", 0.0)
	m.set_shader_parameter("cleat", 0.0)
	for param in [["albedo_tex", "diff"], ["normal_tex", "nor_gl"],
			["rough_tex", "rough"], ["ao_tex", "ao"]]:
		var tex: Texture2D = load(ConveyorKit.TEX % [asset, asset, param [1]])
		if tex == null:
			push_warning("StructureKit: missing %s map for '%s'" % [param [1], asset])
			continue
		m.set_shader_parameter(param [0], tex)
	return m


static func _box(size: Vector3, offset: Vector3) -> ArrayMesh:
	var h:= size * 0.5
	var verts:= PackedVector3Array()
	var normals:= PackedVector3Array()
	var uvs:= PackedVector2Array()
	var indices:= PackedInt32Array()


	var faces:= [
		[Vector3.RIGHT, 2, 1], [Vector3.LEFT, 2, 1],
		[Vector3.UP, 0, 2], [Vector3.DOWN, 0, 2],
		[Vector3.BACK, 0, 1], [Vector3.FORWARD, 0, 1],
	]
	for face in faces:
		var normal: Vector3 = face [0]
		var ui: int = face [1]
		var vi: int = face [2]
		var u_axis:= _axis(ui)
		var v_axis:= _axis(vi)


		if u_axis.cross(v_axis).dot(normal) < 0.0:
			var swap_axis:= u_axis
			u_axis = v_axis
			v_axis = swap_axis
			var swap_i:= ui
			ui = vi
			vi = swap_i
		var centre:= normal * normal.abs().dot(h) + offset
		var eu: float = h [ui]
		var ev: float = h [vi]
		var base:= verts.size()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1),
				Vector2(-1, 1)]:
			verts.append(centre + u_axis * (eu * corner.x) + v_axis * (ev * corner.y))
			normals.append(normal)


			uvs.append(Vector2(eu + eu * corner.x, ev + ev * corner.y))
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])

	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = verts
	arrays [Mesh.ARRAY_NORMAL] = normals
	arrays [Mesh.ARRAY_TEX_UV] = uvs
	arrays [Mesh.ARRAY_INDEX] = indices
	var mesh:= ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _axis(i: int) -> Vector3:
	match i:
		0:
			return Vector3.RIGHT
		1:
			return Vector3.UP
		_:
			return Vector3.BACK
