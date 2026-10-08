class_name Warehouse
extends Node3D


signal rebuilt


const INNER:= 17.0


const SHELL_META:= &"shed_shell"


var inner:= INNER


var follow_tech:= true


enum Wall { Z_POS, Z_NEG, X_POS, X_NEG }


var door_void: Dictionary = { }
const WALL_H:= 9.5
const WALL_T:= 0.5
const KICK_H:= 2.6


const ROOF_GAP:= 23.0


const VOID_LAP:= 0.02
const COL_SPACING:= 5.6
const TEX:= "res://assets/downloaded/textures/%s/%s_%s_%s.%s"


const FLOOR_TEX:= "concrete_floor_worn_02"


const FLOOR_TILE_M:= 2.0


const KICK_TEX:= "concrete_layers"
const KICK_TILE_M:= 1.55

var _mat_floor: StandardMaterial3D
var _mat_clad: StandardMaterial3D


var _mat_roof: StandardMaterial3D
var _mat_kick: StandardMaterial3D
var _mat_steel: StandardMaterial3D


var _floor_mi: MeshInstance3D


var _floor_res:= ""


func _ready() -> void:
	_build_materials()
	if follow_tech:
		inner = _base_inner() + Tech.warehouse_extra()
		Tech.tech_changed.connect(_on_tech_changed)
		Tech.tech_reset.connect(_follow_tech)
	Cfg.gfx_changed.connect(_on_gfx_changed)
	_build_shell()


func _build_shell() -> void:
	_build_floor()
	_build_walls()
	_build_columns()
	_build_roof()
	_build_gables()
	rebuilt.emit()


func column_pitch() -> float:
	return inner * 2.0 / float(_column_bays())


func _column_bays() -> int:
	return maxi(1, int(inner * 2.0 / COL_SPACING))


func bay_centre(at: float) -> float:
	var pitch:= column_pitch()
	var bays:= _column_bays()
	var i:= roundi((at + inner) / pitch - 0.5)
	return - inner + (clampi(i, 0, bays - 1) + 0.5) * pitch


static func long_bays() -> int:
	return Cfg.shed_long_bays


static func long_for(half: float) -> float:
	var bays:= maxi(1, int(half * 2.0 / COL_SPACING))
	return long_bays() * half * 2.0 / float(bays)


func long_z() -> float:
	return long_for(inner)


func z_lo() -> float:
	return - inner - long_z()


func span_z() -> float:
	return inner * 2.0 + long_z()


func z_mid() -> float:
	return - long_z() * 0.5


func encloses(p: Vector3, margin:= 0.0) -> bool:
	return absf(p.x) <= inner + margin and p.z >= z_lo() - margin and p.z <= inner + margin


func _wall_at(i: int) -> float:
	match i:
		Wall.Z_POS, Wall.X_POS:
			return inner + WALL_T * 0.5
		Wall.Z_NEG:
			return z_lo() - WALL_T * 0.5
	return - (inner + WALL_T * 0.5)


func _wall_run(i: int) -> Vector2:
	if i < 2:
		return Vector2(- inner, inner)
	return Vector2(z_lo(), inner)


func floor_y(_at: Vector3) -> float:
	return 0.0


func _on_tech_changed(id: String, _rank: int) -> void:


	if id == "yard_space":
		_follow_tech()


func _base_inner() -> float:
	return Cfg.yard_inner_for_pile()


func _follow_tech() -> void:
	var want:= _base_inner() + Tech.warehouse_extra()
	if is_equal_approx(want, inner):
		return
	inner = want
	for child in get_children():
		child.queue_free()
		remove_child(child)
	_build_shell()


func _tex(asset: String, map: String, res: String) -> Texture2D:
	var ext:= "png" if map == "disp" else "jpg"
	return load(TEX % [asset, asset, map, res, ext]) as Texture2D


func _pbr(asset: String, scale: float, tint:= Color.WHITE, rough_mul:= 1.0,
		res:= "1k") -> StandardMaterial3D:
	var m:= StandardMaterial3D.new()
	var diff:= _tex(asset, "diff", res)
	if diff == null:
		push_warning("Warehouse: missing texture set '%s', falling back to flat" % asset)
		m.albedo_color = tint
		return m
	m.albedo_texture = diff
	m.albedo_color = tint
	var nrm:= _tex(asset, "nor_gl", res)
	if nrm != null:
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = 1.0
	var rgh:= _tex(asset, "rough", res)
	if rgh != null:
		m.roughness_texture = rgh
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = rough_mul
	var ao:= _tex(asset, "ao", res)
	if ao != null:
		m.ao_enabled = true
		m.ao_texture = ao
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.6
	m.metallic = 0.0


	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)


	m.uv1_triplanar_sharpness = 8.0
	return m


const TEX_LINEAR_MEAN:= {
	"concrete_floor_worn_02": 0.156,
	"concrete_wall_003": 0.517,
	"worn_corrugated_iron": 0.189,
}


func _macro_breakup(m: StandardMaterial3D, asset: String, tile: float,
		res:= "1k") -> void:
	var tex:= _tex(asset, "diff", res)
	if tex == null:
		return
	var mean: float = TEX_LINEAR_MEAN.get(asset, 0.5)


	var c:= m.albedo_color.srgb_to_linear()
	var lit:= Color(c.r / mean, c.g / mean, c.b / mean).linear_to_srgb()
	lit.a = m.albedo_color.a
	m.albedo_color = lit
	m.detail_enabled = true
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_albedo = tex
	m.uv2_triplanar = true
	m.uv2_world_triplanar = true
	m.uv2_scale = Vector3(tile, tile, tile)
	m.uv2_triplanar_sharpness = 4.0


func _build_materials() -> void:


	_mat_floor = _floor_material()


	_mat_kick = _pbr(KICK_TEX, 1.0 / KICK_TILE_M, Color(0.94, 0.96, 1.0))


	_mat_clad = _pbr("worn_corrugated_iron", 0.26, Color(0.8, 0.775, 0.73))
	_mat_clad.metallic = 0.0
	_mat_clad.metallic_specular = 0.45
	_mat_clad.roughness = 0.85


	_mat_steel = _pbr("rusty_metal_03", 0.45, Color(0.42, 0.385, 0.345))
	_mat_steel.metallic = 0.15
	_mat_steel.metallic_specular = 0.5
	_mat_steel.roughness = 0.72


	_mat_steel.rim_enabled = true
	_mat_steel.rim = 0.3
	_mat_steel.rim_tint = 0.35


	_mat_roof = _pbr("worn_corrugated_iron", 0.34, Color(0.63, 0.625, 0.615))
	_mat_roof.metallic = 0.0
	_mat_roof.metallic_specular = 0.38
	_mat_roof.roughness = 0.92
	_mat_roof.normal_scale = 1.3


	_macro_breakup(_mat_clad, "concrete_floor_worn_02", 0.055)


func _floor_material() -> StandardMaterial3D:
	var res:= Cfg.texture_res()
	_floor_res = res


	var m:= _pbr(FLOOR_TEX, 1.0 / FLOOR_TILE_M, Color(0.78, 0.76, 0.72),
		1.0, res)
	m.uv1_triplanar = false
	m.uv1_world_triplanar = false


	var height:= _tex(FLOOR_TEX, "disp", res)
	if height != null:
		m.heightmap_enabled = true
		m.heightmap_texture = height


		m.heightmap_scale = 0.5
		m.heightmap_deep_parallax = true
		m.heightmap_min_layers = 8
		m.heightmap_max_layers = 32


	m.normal_scale = 1.15


	m.ao_light_affect = 0.75


	return m


func _on_gfx_changed() -> void:
	if Cfg.texture_res() == _floor_res:
		return
	_mat_floor = _floor_material()
	if _floor_mi != null:
		_floor_mi.material_override = _mat_floor

	_scale_floor_uv()


func _box(size: Vector3, pos: Vector3, mat: Material, collide: bool,
		rot: Vector3 = Vector3.ZERO) -> Node3D:
	var root:= Node3D.new()
	root.position = pos
	root.rotation = rot
	var mesh:= BoxMesh.new()
	mesh.size = size
	var mi:= MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	root.add_child(mi)
	if collide:
		var body:= StaticBody3D.new()
		body.collision_layer = Cfg.L_WORLD
		body.collision_mask = 0
		body.set_meta(SHELL_META, true)
		var cs:= CollisionShape3D.new()
		var shape:= BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)
	add_child(root)
	return root


func _build_floor() -> void:
	_scale_floor_uv()
	var root:= _box(Vector3(inner * 2.0, 0.5, span_z()), Vector3(0, -0.25, z_mid()),
		_mat_floor, true)
	_floor_mi = root.get_child(0) as MeshInstance3D

	for c in root.get_children():
		c.remove_meta(SHELL_META)


func _scale_floor_uv() -> void:
	_mat_floor.uv1_scale = Vector3(inner * 2.0 / FLOOR_TILE_M,
		span_z() / FLOOR_TILE_M, 1.0)


func set_door_void(w: Wall, along: float, width: float, height: float) -> void:
	door_void = { "wall": int(w), "along": along, "width": width, "height": height }
	if is_inside_tree():
		_follow_tech()


func _void_on(i: int) -> Dictionary:
	if door_void.is_empty() or int(door_void ["wall"]) != i:
		return { }
	var horizontal:= i < 2
	var sgn:= 1.0 if i % 2 == 0 else -1.0
	var at:= _wall_at(i)
	var c: float = bay_centre(door_void ["along"])
	var w: float = door_void ["width"]


	var probe:= Vector3(c, 0.0, at - WALL_T * sgn) if horizontal else Vector3(at - WALL_T * sgn, 0.0, c)
	var sill:= floor_y(probe)
	return {
		"c0": c - w * 0.5 + VOID_LAP, "c1": c + w * 0.5 - VOID_LAP,
		"y0": sill + VOID_LAP,
		"y1": sill + float(door_void ["height"]) - VOID_LAP,
	}


func _wall_band(i: int, y0: float, y1: float, mat: Material) -> void:


	var run:= _wall_run(i)
	var c0:= run.x - WALL_T
	var c1:= run.y + WALL_T
	var horizontal:= i < 2
	var at:= _wall_at(i)
	var v:= _void_on(i)
	if v.is_empty() or v ["y1"] <= y0 or v ["y0"] >= y1:
		_wall_slab(horizontal, at, c0, c1, y0, y1, mat)
		return
	_wall_slab(horizontal, at, c0, v ["c0"], y0, y1, mat)
	_wall_slab(horizontal, at, v ["c1"], c1, y0, y1, mat)
	_wall_slab(horizontal, at, v ["c0"], v ["c1"], y0, minf(v ["y0"], y1), mat)
	_wall_slab(horizontal, at, v ["c0"], v ["c1"], maxf(v ["y1"], y0), y1, mat)


func _wall_slab(horizontal: bool, at: float, c0: float, c1: float,
		y0: float, y1: float, mat: Material) -> void:
	var length:= c1 - c0
	var height:= y1 - y0
	if length <= 0.001 or height <= 0.001:
		return
	var c:= (c0 + c1) * 0.5
	var y:= (y0 + y1) * 0.5
	var size:= Vector3(length, height, WALL_T) if horizontal else Vector3(WALL_T, height, length)
	var pos:= Vector3(c, y, at) if horizontal else Vector3(at, y, c)
	_box(size, pos, mat, true)


func _build_walls() -> void:
	for i in 4:
		_wall_band(i, 0.0, KICK_H, _mat_kick)
		_wall_band(i, KICK_H, WALL_H, _mat_clad)
		_grime_band(i)
	_build_apron()


const SKIRT_H:= 0.85


const SKIRT_DARK:= 0.74


const SKIRT_OUT:= 0.012

var _mat_grime: StandardMaterial3D


func _grime_band(i: int) -> void:
	var run:= _wall_run(i)
	var v:= _void_on(i)
	if v.is_empty() or v ["y0"] >= SKIRT_H:
		_grime_panel(i, run.x, run.y)
		return
	_grime_panel(i, run.x, v ["c0"])
	_grime_panel(i, v ["c1"], run.y)


func _grime_panel(i: int, c0: float, c1: float) -> void:
	var length:= c1 - c0
	if length <= 0.001:
		return
	var horizontal:= i < 2
	var sgn:= 1.0 if i % 2 == 0 else -1.0

	var face:= _wall_at(i) - (WALL_T * 0.5 + SKIRT_OUT) * sgn
	var c:= (c0 + c1) * 0.5
	var plane:= PlaneMesh.new()
	plane.size = Vector2(length, SKIRT_H)
	plane.orientation = PlaneMesh.FACE_Z
	var mi:= MeshInstance3D.new()
	mi.name = "Grime"
	mi.mesh = plane
	mi.material_override = _grime_material()
	mi.position = Vector3(c, SKIRT_H * 0.5, face) if horizontal else Vector3(face, SKIRT_H * 0.5, c)


	mi.rotation.y = wall_yaw(i) + PI


	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)


func _grime_material() -> StandardMaterial3D:
	if _mat_grime != null:
		return _mat_grime
	var ramp:= Gradient.new()

	ramp.set_color(0, Color(1.0, 1.0, 1.0))
	ramp.set_color(1, Color(SKIRT_DARK, SKIRT_DARK * 0.985, SKIRT_DARK * 0.95))


	ramp.add_point(0.55, Color(0.965, 0.962, 0.955))
	var tex:= GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 4
	tex.height = 128
	_mat_grime = StandardMaterial3D.new()
	_mat_grime.albedo_texture = tex
	_mat_grime.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_grime.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_grime.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	_mat_grime.cull_mode = BaseMaterial3D.CULL_BACK


	_mat_grime.no_depth_test = false
	_mat_grime.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return _mat_grime


func yard_fence() -> YardFence:
	var ground:= get_node_or_null(NodePath("YardGround"))
	if ground == null:
		return null
	return ground.get_node_or_null(NodePath("YardFence")) as YardFence


static func wall_yaw(w: int) -> float:
	return [0.0, PI, PI * 0.5, - PI * 0.5] [w]


func _build_apron() -> void:
	if door_void.is_empty():
		return
	var i:= int(door_void ["wall"])
	var horizontal:= i < 2
	var sgn:= 1.0 if i % 2 == 0 else -1.0
	var face:= _wall_at(i) + WALL_T * 0.5 * sgn
	var c: float = bay_centre(door_void ["along"])
	var ground:= YardGround.new()
	ground.name = "YardGround"
	ground.position = Vector3(c, 0.0, face) if horizontal else Vector3(face, 0.0, c)
	ground.rotation.y = wall_yaw(i)


	var flip:= 1.0 if i == Wall.Z_POS or i == Wall.X_NEG else -1.0
	var run:= _wall_run(i)
	var e0:= run.x - WALL_T
	var e1:= run.y + WALL_T
	ground.wall_x0 = minf(flip * (e0 - c), flip * (e1 - c))
	ground.wall_x1 = maxf(flip * (e0 - c), flip * (e1 - c))
	ground.shed_depth = (span_z() if horizontal else inner * 2.0) + WALL_T * 2.0
	add_child(ground)


const FRAME_BITE:= 0.01


const COL_HALF:= 0.15
const RAIL_HALF:= 0.11


func _build_columns() -> void:
	var n:= _column_bays()
	var pitch:= column_pitch()


	for i in range(- long_bays(), n + 1):
		var t:= - inner + i * pitch
		for sgn: float in [-1.0, 1.0]:
			var at:= (inner + FRAME_BITE - COL_HALF) * sgn

			_box(Vector3(0.16, WALL_H, 0.34), Vector3(at, WALL_H * 0.5, t), _mat_steel, false)
			_box(Vector3(0.3, WALL_H, 0.06), Vector3(at, WALL_H * 0.5, t - 0.16), _mat_steel, false)

	var z_at:= [inner + FRAME_BITE - COL_HALF, z_lo() - FRAME_BITE + COL_HALF]
	for i in range(n + 1):
		var t:= - inner + i * pitch
		for at: float in z_at:
			_box(Vector3(0.34, WALL_H, 0.16), Vector3(t, WALL_H * 0.5, at), _mat_steel, false)
			_box(Vector3(0.06, WALL_H, 0.3), Vector3(t - 0.16, WALL_H * 0.5, at), _mat_steel, false)
	_build_eaves_rail()


func _build_eaves_rail() -> void:
	var half:= _eave_x()
	var y:= WALL_H - 0.21


	var at:= inner + FRAME_BITE - RAIL_HALF
	var z_back:= z_lo() - FRAME_BITE + RAIL_HALF
	var z_end:= z_lo() - WALL_T
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bar(st, Vector3(- half, y, at), Vector3(half, y, at), 0.22, 0.42)
	_bar(st, Vector3(- half, y, z_back), Vector3(half, y, z_back), 0.22, 0.42)
	for sgn: float in [-1.0, 1.0]:
		_bar(st, Vector3(at * sgn, y, z_end), Vector3(at * sgn, y, half), 0.22, 0.42)
	_steel_mesh(st, "EavesRail")


func roof_gap() -> float:
	return inner * (ROOF_GAP / INNER)


const VAULT_RISE:= 0.36


const EAVE_OUT:= 0.8


const ROOF_OVER_Z:= 0.55


const ARC_SEGS:= 16


const ROOF_T:= 0.2


func _eave_x() -> float:
	return inner + WALL_T


func _vault() -> Vector2:
	var e:= _eave_x()
	var crown:= e * VAULT_RISE
	return Vector2((e * e + crown * crown) / (2.0 * crown), crown)


func roof_curve(x: float) -> float:
	var v:= _vault()
	var r:= v.x
	var d:= minf(absf(x), r - 0.001)
	return v.y - r + sqrt(r * r - d * d)


func _build_roof() -> void:


	var lip:= roof_gap() * 0.5
	var out_x:= _eave_x() + EAVE_OUT


	var depth:= span_z() + WALL_T * 2.0 + ROOF_OVER_Z * 2.0
	for sgn: float in [-1.0, 1.0]:
		_shell_mesh(sgn, lip, out_x, depth)
	_build_eaves(out_x, depth)
	_build_verges(lip, out_x, depth)
	_build_purlins(lip, out_x)
	_build_ribs(lip)


func _build_verges(lip: float, out_x: float, depth: float) -> void:
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sgn: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_sweep_beam(st, lip * sgn, out_x * sgn,
				z_mid() + z * (depth * 0.5 - 0.07), 0.14, 0.34, -0.05, ARC_SEGS)
	_steel_mesh(st, "Verges")


func _clear_span() -> float:
	return span_z() - 0.06


func _shell_mesh(sgn: float, lip: float, out_x: float, depth: float) -> void:
	var v:= _vault()


	var cy:= WALL_H + v.y - v.x
	var step:= (out_x - lip) / float(ARC_SEGS)
	var outer: Array [Vector2] = []
	var soffit: Array [Vector2] = []
	var norm: Array [Vector2] = []
	for i in ARC_SEGS + 1:
		var x:= lip + i * step
		var p:= Vector2(x * sgn, WALL_H + roof_curve(x))
		var n:= (p - Vector2(0.0, cy)).normalized()
		outer.append(p)
		norm.append(n)
		soffit.append(p - n * ROOF_T)

	var z0:= z_mid() - depth * 0.5
	var z1:= z_mid() + depth * 0.5
	var back:= Vector3(0, 0, -1)
	var front:= Vector3(0, 0, 1)
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ARC_SEGS:
		var n0:= Vector3(norm [i].x, norm [i].y, 0.0)
		var n1:= Vector3(norm [i + 1].x, norm [i + 1].y, 0.0)
		var oa:= _at(outer [i], z0)
		var ob:= _at(outer [i + 1], z0)
		var oc:= _at(outer [i + 1], z1)
		var od:= _at(outer [i], z1)
		var sa:= _at(soffit [i], z0)
		var sb:= _at(soffit [i + 1], z0)
		var sc:= _at(soffit [i + 1], z1)
		var sd:= _at(soffit [i], z1)


		_quad(st, [oa, ob, oc, od], [n0, n1, n1, n0])
		_quad(st, [sa, sb, sc, sd], [- n0, - n1, - n1, - n0])

		_quad(st, [oa, ob, sb, sa], [back, back, back, back])
		_quad(st, [od, oc, sc, sd], [front, front, front, front])


	var last:= ARC_SEGS
	var t_lip:= (outer [0] - outer [1]).normalized()
	var t_eave:= (outer [last] - outer [last - 1]).normalized()
	var n_lip:= Vector3(t_lip.x, t_lip.y, 0.0)
	var n_eave:= Vector3(t_eave.x, t_eave.y, 0.0)
	_quad(st, [_at(outer [0], z0), _at(soffit [0], z0), _at(soffit [0], z1),
		_at(outer [0], z1)], [n_lip, n_lip, n_lip, n_lip])
	_quad(st, [_at(outer [last], z0), _at(soffit [last], z0),
		_at(soffit [last], z1), _at(outer [last], z1)],
		[n_eave, n_eave, n_eave, n_eave])

	var mesh:= st.commit()
	var mi:= MeshInstance3D.new()
	mi.name = "Shell%s" % ("P" if sgn > 0.0 else "N")
	mi.mesh = mesh
	mi.material_override = _mat_roof
	add_child(mi)


	var body:= StaticBody3D.new()
	body.collision_layer = Cfg.L_WORLD
	body.collision_mask = 0
	body.set_meta(SHELL_META, true)
	var cs:= CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	mi.add_child(body)


func _at(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)


func _quad(st: SurfaceTool, p: Array, n: Array) -> void:
	var wound: Vector3 = (p [1] - p [0]).cross(p [2] - p [0])
	var order:= [0, 1, 2, 0, 2, 3] if wound.dot(n [0]) < 0.0 else [0, 3, 2, 0, 2, 1]
	for i: int in order:
		st.set_normal(n [i])
		st.add_vertex(p [i])


const BAR_CORNER:= 3


static func _bar_section(w: float, d: float) -> Array:
	var r: float = minf(w, d) * 0.34
	var hw:= w * 0.5 - r
	var hd:= d * 0.5 - r
	var centres:= [Vector2(hw, hd), Vector2(- hw, hd), Vector2(- hw, - hd),
		Vector2(hw, - hd)]
	var pts: Array [Vector2] = []
	var nrm: Array [Vector2] = []
	for c in 4:
		for i in BAR_CORNER + 1:
			var a:= PI * 0.5 * (float(c) + float(i) / float(BAR_CORNER))
			var n:= Vector2(cos(a), sin(a))
			nrm.append(n)
			pts.append(centres [c] + n * r)
	return [pts, nrm]


func _skin(st: SurfaceTool, frames: Array, sec: Array, nrm: Array) -> void:
	var k: int = sec.size()
	var rings: Array [PackedVector3Array] = []
	var rn: Array [PackedVector3Array] = []
	for f: Array in frames:
		var o: Vector3 = f [0]
		var u: Vector3 = f [1]
		var v: Vector3 = f [2]
		var pr:= PackedVector3Array()
		var nr:= PackedVector3Array()
		for i in k:
			pr.append(o + u * sec [i].x + v * sec [i].y)
			nr.append((u * nrm [i].x + v * nrm [i].y).normalized())
		rings.append(pr)
		rn.append(nr)
	for s in rings.size() - 1:
		for i in k:
			var j:= (i + 1) % k
			_quad(st, [rings [s] [i], rings [s] [j], rings [s + 1] [j], rings [s + 1] [i]],
				[rn [s] [i], rn [s] [j], rn [s + 1] [j], rn [s + 1] [i]])
	for e: int in [0, rings.size() - 1]:
		var o: Vector3 = frames [e] [0]
		var axis: Vector3 = (frames [e] [1] as Vector3).cross(frames [e] [2]).normalized()
		var face:= axis * (-1.0 if e == 0 else 1.0)
		for i in k:
			var j:= (i + 1) % k
			var tri:= [o, rings [e] [i], rings [e] [j]]
			if ((tri [1] - tri [0]) as Vector3).cross(tri [2] - tri [0]).dot(face) >= 0.0:
				tri = [o, rings [e] [j], rings [e] [i]]
			for p: Vector3 in tri:
				st.set_normal(face)
				st.add_vertex(p)


func _bar(st: SurfaceTool, a: Vector3, b: Vector3, w: float, h: float) -> void:
	var dir:= (b - a).normalized()
	var v:= Vector3.UP

	var u:= v.cross(dir)
	var sec:= _bar_section(w, h)
	_skin(st, [[a, u, v], [b, u, v]], sec [0], sec [1])


func _sweep_beam(st: SurfaceTool, x0: float, x1: float, z: float, w: float,
		d: float, drop: float, segs: int) -> void:
	var v:= _vault()
	var cy:= WALL_H + v.y - v.x
	var sec:= _bar_section(w, d)
	var frames: Array = []
	for i in segs + 1:
		var x: float = x0 + (x1 - x0) * float(i) / float(segs)
		var p:= Vector2(x, WALL_H + roof_curve(x))
		var n:= (p - Vector2(0.0, cy)).normalized()


		var c:= p - n * (drop + d * 0.5)


		frames.append([Vector3(c.x, c.y, z), Vector3(0, 0, 1),
			Vector3(n.x, n.y, 0.0)])
	_skin(st, frames, sec [0], sec [1])


func _steel_mesh(st: SurfaceTool, name: String) -> void:
	var mi:= MeshInstance3D.new()
	mi.name = name
	mi.mesh = st.commit()
	mi.material_override = _mat_steel
	add_child(mi)


func _build_eaves(out_x: float, depth: float) -> void:
	var lip:= roof_gap() * 0.5
	var v:= _vault()
	var cy:= WALL_H + v.y - v.x


	var pe:= Vector2(out_x, WALL_H + roof_curve(out_x))
	var ne:= (pe - Vector2(0.0, cy)).normalized()
	var seat:= pe - ne * (ROOF_T + 0.13)
	var flash_y:= WALL_H + roof_curve(lip)
	for sgn: float in [-1.0, 1.0]:
		_box(Vector3(0.34, 0.26, depth), Vector3(seat.x * sgn, seat.y, z_mid()),
			_mat_steel, false)
		_box(Vector3(0.38, 0.16, _clear_span()),
			Vector3(lip * sgn, flash_y + 0.02, z_mid()), _mat_steel, false)


func _build_purlins(lip: float, out_x: float) -> void:
	var step:= (out_x - lip) / float(ARC_SEGS)
	var half:= _clear_span() * 0.5
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, ARC_SEGS, 3):
		var x:= lip + i * step
		if x > _eave_x():
			continue
		for sgn: float in [-1.0, 1.0]:
			_purlin(st, x * sgn, half, 0.14, 0.24, ROOF_T + 0.02)
	_steel_mesh(st, "Purlins")


func _purlin(st: SurfaceTool, x: float, half: float, w: float, d: float,
		drop: float) -> void:
	var seat:= _seat(x, drop + d * 0.5)
	var n:= _radial(x)
	var v:= Vector3(n.x, n.y, 0.0)
	var dir:= Vector3(0, 0, 1)

	var u:= v.cross(dir)
	var sec:= _bar_section(w, d)
	_skin(st, [[Vector3(seat.x, seat.y, z_mid() - half), u, v],
		[Vector3(seat.x, seat.y, z_mid() + half), u, v]], sec [0], sec [1])


func _build_ribs(lip: float) -> void:
	var span:= inner * 2.0 - 0.06
	var n:= maxi(1, int(span / (COL_SPACING * 1.5)))
	var step:= span / float(n)
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(n + 1):
		var z:= - span * 0.5 + i * step
		_sweep_beam(st, - lip, lip, z, 0.2, 0.26, 0.0, 20)
	var more:= long_z()
	var m:= ceili(more / step)
	for i in range(1, m + 1):
		var z:= - span * 0.5 - i * (more / float(m))
		_sweep_beam(st, - lip, lip, z, 0.2, 0.26, 0.0, 20)
	_steel_mesh(st, "Ribs")


func _radial(x: float) -> Vector2:
	var v:= _vault()
	var cy:= WALL_H + v.y - v.x
	var p:= Vector2(x, WALL_H + roof_curve(x))
	return (p - Vector2(0.0, cy)).normalized()


func _seat(x: float, drop: float) -> Vector2:
	return Vector2(x, WALL_H + roof_curve(x)) - _radial(x) * drop


func _build_gables() -> void:
	var lip:= roof_gap() * 0.5
	if lip >= inner:
		return
	for i in 2:
		var sgn:= 1.0 if i == 0 else -1.0
		_gable_panel(i, sgn)


func _gable_panel(i: int, sgn: float) -> void:
	var lip:= roof_gap() * 0.5
	var e:= _eave_x()

	var face:= inner if sgn > 0.0 else - z_lo()
	var z_out:= (face + WALL_T) * sgn
	var z_in:= face * sgn
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step:= (e - lip) / float(ARC_SEGS)


	var y_low:= WALL_H - 0.02
	for half: float in [-1.0, 1.0]:
		for j in ARC_SEGS:
			var x0:= (lip + j * step) * half
			var x1:= (lip + (j + 1) * step) * half


			var y0:= WALL_H + roof_curve(x0) - 0.02
			var y1:= WALL_H + roof_curve(x1) - 0.02
			_gable_slice(st, x0, x1, y_low, y0, y1, z_out, z_in, sgn)
			if j == 0:
				_gable_cap(st, x0, y_low, y0, z_out, z_in, Vector3(- half, 0, 0))
			if j == ARC_SEGS - 1:
				_gable_cap(st, x1, y_low, y1, z_out, z_in, Vector3(half, 0, 0))
	var mi:= MeshInstance3D.new()
	mi.name = "Gable%d" % i
	mi.mesh = st.commit()
	mi.material_override = _mat_clad
	add_child(mi)


func _gable_slice(st: SurfaceTool, x0: float, x1: float, y_low: float,
		y0: float, y1: float, z_out: float, z_in: float, sgn: float) -> void:
	var out_n:= Vector3(0, 0, sgn)
	_quad(st, [Vector3(x0, y_low, z_out), Vector3(x1, y_low, z_out),
		Vector3(x1, y1, z_out), Vector3(x0, y0, z_out)],
		[out_n, out_n, out_n, out_n])
	_quad(st, [Vector3(x0, y_low, z_in), Vector3(x1, y_low, z_in),
		Vector3(x1, y1, z_in), Vector3(x0, y0, z_in)],
		[- out_n, - out_n, - out_n, - out_n])


	var up:= Vector3.UP
	_quad(st, [Vector3(x0, y0, z_out), Vector3(x1, y1, z_out),
		Vector3(x1, y1, z_in), Vector3(x0, y0, z_in)], [up, up, up, up])
	var down:= Vector3.DOWN
	_quad(st, [Vector3(x0, y_low, z_out), Vector3(x1, y_low, z_out),
		Vector3(x1, y_low, z_in), Vector3(x0, y_low, z_in)],
		[down, down, down, down])


func _gable_cap(st: SurfaceTool, x: float, y_low: float, y_top: float,
		z_out: float, z_in: float, face: Vector3) -> void:
	if y_top - y_low <= 0.001:
		return
	_quad(st, [Vector3(x, y_low, z_out), Vector3(x, y_top, z_out),
		Vector3(x, y_top, z_in), Vector3(x, y_low, z_in)],
		[face, face, face, face])
