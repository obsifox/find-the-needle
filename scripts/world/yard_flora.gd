class_name YardFlora
extends RefCounted


const TEX:= "res://assets/downloaded/textures/%s/%s_%s_1k.webp"


const TEX_DRY:= 0
const TEX_PASTURE:= 1
const TEX_TRACK:= 2
const TEX_ROCK:= 3


const MESH_TREE:= 0
const MESH_BUSH:= 1
const MESH_GRASS:= 2


const UV_SCALE:= [0.14, 0.2, 0.22, 0.1]


const DETILE_ROTATION:= [0.18, 0.0, 0.18, 0.161]
const DETILE_SHIFT:= [0.35, 0.0, 0.35, 0.0]


const SOW_R:= 470.0

const GRASS_R:= 165.0


const SEED:= 74003


const CLEAR:= 0.12

var terrain: Terrain3D
var track_yaw:= 0.0


var counts:= { }

var _rng:= RandomNumberGenerator.new()
var _data: Terrain3DData


const FLORA_DIR:= "res://assets/terrain/flora"
const LIBRARY:= "res://assets/terrain/yard_assets.tres"


const FLORA_FILES:= ["tree", "hedge_bush", "grass_tuft"]


static func save_library() -> Terrain3DAssets:
	DirAccess.make_dir_recursive_absolute(FLORA_DIR)
	for slot in FLORA_FILES.size():
		var err:= ResourceSaver.save(_build_plant(slot), plant_path(slot))
		if err != OK:
			push_error("YardFlora: could not write %s (%d)" % [plant_path(slot), err])
			return build_assets()
	var a:= build_assets()
	var err:= ResourceSaver.save(a, LIBRARY, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		push_error("YardFlora: could not write %s (%d)" % [LIBRARY, err])
	return a


static func plant_path(slot: int) -> String:
	return "%s/%s.tscn" % [FLORA_DIR, FLORA_FILES [slot]]


static func _plant_scene(slot: int) -> PackedScene:
	if ResourceLoader.exists(plant_path(slot)):
		var packed: PackedScene = load(plant_path(slot))
		if packed != null:
			return packed
	return _build_plant(slot)


static func _build_plant(slot: int) -> PackedScene:
	match slot:
		MESH_TREE:
			return _lod_scene("Tree", [_tree_mesh(0), _tree_mesh(1), _tree_mesh(2)])
		MESH_BUSH:
			return _lod_scene("Bush", [_bush_mesh(0), _bush_mesh(1)])
		_:
			return _lod_scene("Grass", [_grass_mesh()])


static func build_assets() -> Terrain3DAssets:
	var a:= Terrain3DAssets.new()
	a.set_texture(TEX_DRY, _ground("withered_grass", "Dry field", TEX_DRY,
		Color(1.0, 0.96, 0.62), 1.0, 0.02))


	a.set_texture(TEX_PASTURE, _ground("ground037", "Pasture", TEX_PASTURE,
		Color(0.55, 0.72, 0.45), 1.0, -0.05))
	a.set_texture(TEX_TRACK, _ground("gravel_road", "Track", TEX_TRACK,
		Color(0.68, 0.65, 0.6), 1.2, 0.06))
	a.set_texture(TEX_ROCK, _ground("rock023", "Rock", TEX_ROCK,
		Color(0.62, 0.61, 0.6), 1.0, -0.05))

	a.set_mesh_asset(MESH_TREE, _tree_asset())
	a.set_mesh_asset(MESH_BUSH, _bush_asset())
	a.set_mesh_asset(MESH_GRASS, _grass_asset())
	return a


static func _ground(asset: String, label: String, slot: int, tint: Color,
		depth: float, rough: float) -> Terrain3DTextureAsset:
	var t:= Terrain3DTextureAsset.new()
	t.name = label
	t.id = slot
	t.albedo_color = tint
	t.albedo_texture = load(TEX % [asset, asset, "ab"])
	t.normal_texture = load(TEX % [asset, asset, "nr"])
	if t.albedo_texture == null:
		push_warning("YardFlora: missing ground texture '%s'" % asset)
	t.normal_depth = depth
	t.ao_strength = 1.6
	t.roughness = rough
	t.uv_scale = UV_SCALE [slot]


	t.detiling_rotation = DETILE_ROTATION [slot]
	t.detiling_shift = DETILE_SHIFT [slot]
	return t


static func field_noise() -> FastNoiseLite:
	var n:= FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.seed = 21107
	n.frequency = 1.0 / 150.0
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	n.cellular_jitter = 0.92
	return n


static func hedge_noise() -> FastNoiseLite:
	var n:= field_noise()
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	return n


func sow() -> void:
	if terrain == null or terrain.data == null or terrain.instancer == null:
		push_error("YardFlora: nothing to plant on")
		return
	_data = terrain.data
	_rng.seed = SEED
	counts.clear()

	var started:= Time.get_ticks_msec()
	var trees: Array [Transform3D] = []
	var tree_tint:= PackedColorArray()
	var bushes: Array [Transform3D] = []
	var bush_tint:= PackedColorArray()

	_sow_hedges(trees, tree_tint, bushes, bush_tint)
	_sow_copses(trees, tree_tint)
	_emit(MESH_TREE, trees, tree_tint)
	_emit(MESH_BUSH, bushes, bush_tint)
	_sow_grass()

	print("[yard] planted %d trees, %d bushes, %d grass tufts in %d ms"
		% [counts.get(MESH_TREE, 0), counts.get(MESH_BUSH, 0),
			counts.get(MESH_GRASS, 0), Time.get_ticks_msec() - started])


func _emit(slot: int, xf: Array [Transform3D], tint: PackedColorArray) -> void:
	counts [slot] = xf.size()
	if xf.is_empty():
		return
	terrain.instancer.add_transforms(slot, xf, tint)


func _sow_hedges(trees: Array [Transform3D], tree_tint: PackedColorArray,
		bushes: Array [Transform3D], bush_tint: PackedColorArray) -> void:
	var hedge:= hedge_noise()
	const STEP:= 2.2
	var x:= - SOW_R
	while x <= SOW_R:
		var z:= - SOW_R
		while z <= SOW_R:
			var at:= Vector3(x + _rng.randf_range(-1.05, 1.05), 0.0,
				z + _rng.randf_range(-1.05, 1.05))
			z += STEP
			if Vector2(at.x, at.z).length() > SOW_R:
				continue
			if YardTerrain.relief_at(at, track_yaw) < CLEAR:
				continue


			var edge: float = hedge.get_noise_2d(at.x, at.z)
			if edge < -0.4:
				continue
			at.y = _seat(at)
			if is_nan(at.y):
				continue

			var slope:= _slope_at(at)
			if slope > 0.85:
				continue
			var thick:= inverse_lerp(-0.4, 0.0, edge)
			if _rng.randf() > 0.34 + thick * 0.6:
				continue
			if slope < 0.45 and _rng.randf() < 0.2:
				trees.append(_stand(at, _rng.randf_range(0.72, 1.3)))
				tree_tint.append(_leaf_tint())
			else:
				bushes.append(_stand(at, _rng.randf_range(0.8, 1.45)))
				bush_tint.append(_leaf_tint())
		x += STEP


func _sow_copses(trees: Array [Transform3D], tint: PackedColorArray) -> void:
	for _copse in 16:
		var a:= _rng.randf() * TAU
		var r:= _rng.randf_range(FLAT_R_OUT, SOW_R - 60.0)
		var mid:= Vector3(cos(a) * r, 0.0, sin(a) * r)
		if YardTerrain.relief_at(mid, track_yaw) < 0.9:
			continue
		var spread:= _rng.randf_range(13.0, 30.0)
		for _t in _rng.randi_range(14, 42):


			var t_a:= _rng.randf() * TAU
			var t_r:= spread * sqrt(_rng.randf())
			var at:= mid + Vector3(cos(t_a) * t_r, 0.0, sin(t_a) * t_r)
			if YardTerrain.relief_at(at, track_yaw) < CLEAR:
				continue
			if _slope_at(at) > 0.7:
				continue
			at.y = _seat(at)
			if is_nan(at.y):
				continue
			trees.append(_stand(at, _rng.randf_range(0.85, 1.55)))
			tint.append(_leaf_tint())


func _sow_grass() -> void:
	var xf: Array [Transform3D] = []
	var tint:= PackedColorArray()
	var patch:= FastNoiseLite.new()
	patch.seed = 5512
	patch.frequency = 1.0 / 26.0
	var keep_out:= YardTerrain.required_flat() + 2.0
	const STEP:= 1.5
	var x:= - GRASS_R
	while x <= GRASS_R:
		var z:= - GRASS_R
		while z <= GRASS_R:
			var at:= Vector3(x + _rng.randf_range(-0.7, 0.7), 0.0,
				z + _rng.randf_range(-0.7, 0.7))
			z += STEP
			var out:= Vector2(at.x, at.z).length()
			if out > GRASS_R or out < keep_out:
				continue
			if _on_track(at):
				continue

			if _rng.randf() > 0.55 + patch.get_noise_2d(at.x, at.z) * 0.45:
				continue
			if _slope_at(at) > 0.9:
				continue
			at.y = _seat(at)
			if is_nan(at.y):
				continue
			xf.append(_stand(at, _rng.randf_range(0.7, 1.4)))
			tint.append(_leaf_tint())
		x += STEP
	_emit(MESH_GRASS, xf, tint)


const FLAT_R_OUT:= 150.0


const TRACK_CLEAR:= 6.0


func _on_track(at: Vector3) -> bool:
	var u:= at.x * sin(track_yaw) + at.z * cos(track_yaw)
	var v:= at.x * cos(track_yaw) - at.z * sin(track_yaw)
	return u > 0.0 and u < YardGround.ROAD_END + 20.0 and absf(v) < TRACK_CLEAR


func _seat(at: Vector3) -> float:
	return _data.get_height(at)


func _stand(at: Vector3, scale: float) -> Transform3D:
	var b:= Basis.from_euler(Vector3(
		_rng.randf_range(-0.05, 0.05),
		_rng.randf() * TAU,
		_rng.randf_range(-0.05, 0.05)))
	return Transform3D(b.scaled(Vector3(scale, scale * _rng.randf_range(0.9, 1.15), scale)), at)


func _leaf_tint() -> Color:
	var warm:= _rng.randf_range(-0.07, 0.07)
	var lift:= _rng.randf_range(0.88, 1.12)
	return Color(clampf((1.0 + warm) * lift, 0.0, 2.0),
		clampf(lift, 0.0, 2.0),
		clampf((1.0 - warm * 1.4) * lift, 0.0, 2.0), 1.0)


func _slope_at(at: Vector3) -> float:
	var n: Vector3 = _data.get_normal(at)
	if is_nan(n.y) or n.y <= 0.0001:
		return 9.9
	return Vector2(n.x, n.z).length() / n.y


const BARK:= Color(0.29, 0.23, 0.17)
const BARK_LIT:= Color(0.38, 0.31, 0.22)
const LEAF_DARK:= Color(0.16, 0.3, 0.12)
const LEAF_MID:= Color(0.26, 0.44, 0.16)
const LEAF_LIT:= Color(0.42, 0.58, 0.22)
const BLADE_LO:= Color(0.32, 0.38, 0.15)
const BLADE_HI:= Color(0.62, 0.63, 0.28)


static func _foliage_material(backlit: bool) -> StandardMaterial3D:
	var m:= StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true


	m.vertex_color_is_srgb = true
	m.roughness = 0.92
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED


	if backlit:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.backlight_enabled = true
		m.backlight = Color(0.16, 0.22, 0.1)
	return m


static func _tree_asset() -> Terrain3DMeshAsset:
	var a:= Terrain3DMeshAsset.new()
	a.name = "Tree"
	a.id = MESH_TREE
	a.scene_file = _plant_scene(MESH_TREE)


	a.height_offset = -0.25
	a.density = 0.02
	a.last_lod = 2
	a.set_lod_range(0, 62.0)
	a.set_lod_range(1, 220.0)
	a.set_lod_range(2, 700.0)


	a.shadow_impostor = 1
	a.last_shadow_lod = 1
	a.fade_margin = 6.0
	return a


static func _bush_asset() -> Terrain3DMeshAsset:
	var a:= Terrain3DMeshAsset.new()
	a.name = "Hedge bush"
	a.id = MESH_BUSH
	a.scene_file = _plant_scene(MESH_BUSH)
	a.height_offset = -0.3
	a.density = 0.35
	a.last_lod = 1
	a.set_lod_range(0, 74.0)
	a.set_lod_range(1, 460.0)
	a.last_shadow_lod = 0
	a.fade_margin = 5.0
	return a


static func _grass_asset() -> Terrain3DMeshAsset:
	var a:= Terrain3DMeshAsset.new()
	a.name = "Grass tuft"
	a.id = MESH_GRASS
	a.scene_file = _plant_scene(MESH_GRASS)
	a.height_offset = -0.06
	a.density = 2.0
	a.last_lod = 0
	a.set_lod_range(0, 72.0)


	a.cast_shadows = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.last_shadow_lod = 0
	a.fade_margin = 8.0
	return a


static func _lod_scene(label: String, meshes: Array) -> PackedScene:
	var root:= Node3D.new()
	root.name = label
	for i in meshes.size():
		var mi:= MeshInstance3D.new()
		mi.name = "%sLOD%d" % [label, i]
		mi.mesh = meshes [i]
		root.add_child(mi)
		mi.owner = root
	var packed:= PackedScene.new()
	packed.pack(root)
	return packed


static func _tree_mesh(lod: int) -> ArrayMesh:
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:= RandomNumberGenerator.new()


	rng.seed = 9081
	var sides: int = [7, 6, 5] [lod]
	var blobs: int = [6, 3, 2] [lod]

	var height:= 7.2


	var lean:= Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
	var foot:= Vector3.ZERO
	var fork:= Vector3.ZERO
	var last:= foot
	for seg in 3:
		var t:= float(seg + 1) / 3.0
		var top:= Vector3(lean.x * t * t, height * 0.66 * t, lean.z * t * t)
		_tube(st, last, top, lerpf(0.3, 0.13, float(seg) / 3.0),
			lerpf(0.3, 0.13, t), sides, BARK, BARK_LIT)
		last = top
		if seg == 1:
			fork = top
	var crown:= last


	if lod == 0:
		for limb in 4:
			var a:= TAU * limb / 4.0 + rng.randf_range(-0.4, 0.4)
			var reach:= rng.randf_range(1.3, 2.1)
			var tip:= fork + Vector3(cos(a) * reach, rng.randf_range(1.0, 1.9),
				sin(a) * reach)
			_tube(st, fork + Vector3(0.0, rng.randf_range(0.0, 0.7), 0.0), tip,
				0.1, 0.045, 4, BARK, BARK_LIT)


	st.set_smooth_group(0)
	for b in blobs:
		var off:= Vector3.ZERO
		var r:= Vector3(2.7, 2.0, 2.7)
		if blobs > 1:
			var a:= TAU * b / float(blobs) + rng.randf_range(-0.5, 0.5)
			var spread:= rng.randf_range(0.8, 1.9)
			off = Vector3(cos(a) * spread, rng.randf_range(-0.5, 1.2), sin(a) * spread)
			r = Vector3(rng.randf_range(1.7, 2.6), rng.randf_range(1.3, 2.0),
				rng.randf_range(1.7, 2.6))
		_blob(st, crown + Vector3(0.0, 0.7, 0.0) + off, r,
			maxi(3, sides - 1), maxi(2, sides / 2), rng, LEAF_DARK, LEAF_MID, LEAF_LIT)
	st.set_smooth_group(4294967295)

	st.generate_normals()
	st.set_material(_foliage_material(true))
	return st.commit()


static func _bush_mesh(lod: int) -> ArrayMesh:
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:= RandomNumberGenerator.new()
	rng.seed = 3312
	var blobs: int = [4, 2] [lod]
	var sides: int = [6, 4] [lod]
	st.set_smooth_group(0)
	for b in blobs:
		var a:= TAU * b / float(blobs) + rng.randf_range(-0.6, 0.6)
		var spread:= rng.randf_range(0.25, 0.75)
		var at:= Vector3(cos(a) * spread, rng.randf_range(0.55, 1.05), sin(a) * spread)
		_blob(st, at, Vector3(rng.randf_range(0.65, 1.05), rng.randf_range(0.5, 0.85),
			rng.randf_range(0.65, 1.05)), sides, maxi(2, sides / 2), rng,
			LEAF_DARK, LEAF_MID, LEAF_LIT)
	st.set_smooth_group(4294967295)


	if lod == 0:
		for s in 3:
			var a:= TAU * s / 3.0 + rng.randf_range(-0.5, 0.5)
			_tube(st, Vector3(cos(a) * 0.12, 0.0, sin(a) * 0.12),
				Vector3(cos(a) * 0.35, 0.85, sin(a) * 0.35),
				0.075, 0.03, 4, BARK, BARK_LIT)
	st.generate_normals()
	st.set_material(_foliage_material(true))
	return st.commit()


static func _grass_mesh() -> ArrayMesh:
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:= RandomNumberGenerator.new()
	rng.seed = 4471
	for blade in 5:
		var a:= TAU * blade / 5.0 + rng.randf_range(-0.5, 0.5)
		var dir:= Vector3(cos(a), 0.0, sin(a))
		var h:= rng.randf_range(0.3, 0.55)
		var bend:= rng.randf_range(0.14, 0.34)
		var w:= rng.randf_range(0.032, 0.055)
		var side:= dir.cross(Vector3.UP).normalized() * w
		var root:= dir * rng.randf_range(0.0, 0.09)
		var mid:= root + Vector3(0.0, h * 0.6, 0.0) + dir * bend * 0.4
		var tip:= root + Vector3(0.0, h, 0.0) + dir * bend


		_strip(st, root, mid, side, side * 0.65, BLADE_LO, BLADE_HI.lerp(BLADE_LO, 0.5))
		_strip(st, mid, tip, side * 0.65, side * 0.06, BLADE_HI.lerp(BLADE_LO, 0.5), BLADE_HI)
	st.generate_normals()
	st.set_material(_foliage_material(true))
	return st.commit()


static func _tube(st: SurfaceTool, from: Vector3, to: Vector3, r0: float, r1: float,
		sides: int, dark: Color, lit: Color) -> void:
	var axis:= to - from
	if axis.length_squared() < 1e-06:
		return
	var up:= axis.normalized()
	var ref:= Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD
	var u:= up.cross(ref).normalized()
	var v:= up.cross(u)
	for i in sides:
		var a0:= TAU * i / float(sides)
		var a1:= TAU * (i + 1) / float(sides)
		var d0:= u * cos(a0) + v * sin(a0)
		var d1:= u * cos(a1) + v * sin(a1)


		var c0:= dark.lerp(lit, 0.5 + 0.5 * d0.x)
		var c1:= dark.lerp(lit, 0.5 + 0.5 * d1.x)
		_quad(st,
			from + d0 * r0, from + d1 * r0, to + d1 * r1, to + d0 * r1,
			c0.darkened(0.25), c1.darkened(0.25), c1, c0)

	for i in sides:
		var a0:= TAU * i / float(sides)
		var a1:= TAU * (i + 1) / float(sides)
		_tri(st, to, to + (u * cos(a0) + v * sin(a0)) * r1,
			to + (u * cos(a1) + v * sin(a1)) * r1, lit, lit, lit)


static func _blob(st: SurfaceTool, at: Vector3, radius: Vector3, sides: int, rings: int,
		rng: RandomNumberGenerator, dark: Color, mid: Color, lit: Color) -> void:
	var grid:= []
	for ring in rings + 1:
		var phi:= PI * ring / float(rings)
		var row:= []
		var wobble:= rng.randf_range(0.86, 1.14)
		for i in sides:
			var theta:= TAU * i / float(sides)
			var n:= Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			row.append(at + Vector3(n.x * radius.x, n.y * radius.y, n.z * radius.z) * wobble)
		grid.append(row)
	for ring in rings:


		var t0:= 1.0 - float(ring) / float(rings)
		var t1:= 1.0 - float(ring + 1) / float(rings)
		var c0:= (dark.lerp(mid, t0 * 2.0) if t0 < 0.5 else mid.lerp(lit, (t0 - 0.5) * 2.0))
		var c1:= (dark.lerp(mid, t1 * 2.0) if t1 < 0.5 else mid.lerp(lit, (t1 - 0.5) * 2.0))
		for i in sides:
			var j:= (i + 1) % sides
			_quad(st, grid [ring] [i], grid [ring] [j], grid [ring + 1] [j], grid [ring + 1] [i],
				c1, c1, c0, c0)


static func _strip(st: SurfaceTool, from: Vector3, to: Vector3, w0: Vector3, w1: Vector3,
		c0: Color, c1: Color) -> void:
	_quad(st, from - w0, from + w0, to + w1, to - w1, c0, c0, c1, c1)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_tri(st, a, b, c, ca, cb, cc)
	_tri(st, a, c, d, ca, cc, cd)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)
