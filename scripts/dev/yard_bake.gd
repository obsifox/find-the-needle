class_name DevYardBake
extends Node


const RES:= YardTerrain.RES
const CELL:= YardTerrain.CELL


const HILL_H:= 26.0

const HILL_PERIOD:= 620.0

const RIDGE_PERIOD:= 260.0
const RIDGE_H:= 13.0


const WARP:= 90.0


const MOUNT_H:= 205.0


const MOUNT_PERIOD:= 940.0

const MOUNT_DETAIL_PERIOD:= 310.0
const MOUNT_DETAIL:= 0.28


const MOUNT_IN:= 540.0
const MOUNT_OUT:= 1010.0


const DROPS:= 240000


const DROP_STEPS:= 34


const INERTIA:= 0.06


const CAPACITY:= 3.4
const ERODE_RATE:= 0.28
const DEPOSIT_RATE:= 0.22


const MIN_SLOPE:= 0.02
const GRAVITY:= 6.0
const EVAPORATE:= 0.018


const DIRT_SLOPE:= Vector2(0.38, 0.78)
const ROCK_SLOPE:= Vector2(0.45, 0.92)


const LANE_HALF:= 3.1
const LANE_EDGE:= 5.4


var track_yaw:= 0.0

var _heights:= PackedFloat32Array()
var _rng:= RandomNumberGenerator.new()


func run(force: bool) -> void:
	track_yaw = Warehouse.wall_yaw(Warehouse.Wall.X_POS)
	if _has_regions() and not force:
		print("[yardbake] %s already holds a terrain." % YardTerrain.DATA_DIR)
		print("[yardbake] It can be opened and sculpted in the editor with the plugin's")
		print("[yardbake] own brushes, which is the way to change it. Pass --force to")
		print("[yardbake] throw that away and generate a new one.")
		get_tree().quit(1)
		return

	_rng.seed = 4471
	var started:= Time.get_ticks_msec()
	_raise()
	print("[yardbake] %d x %d heights, %.0f m across, in %d ms"
		% [RES, RES, RES * CELL, Time.get_ticks_msec() - started])

	started = Time.get_ticks_msec()
	_erode()
	_smooth(0.45)
	print("[yardbake] %d droplets in %d ms" % [DROPS, Time.get_ticks_msec() - started])

	_flatten_yard()


	var root:= Node3D.new()
	root.name = "Yard"
	var terrain:= Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.region_size = YardTerrain.REGION_SIZE
	terrain.vertex_spacing = CELL


	terrain.mesh_lods = 8
	terrain.mesh_size = 48
	terrain.material = Terrain3DMaterial.new()
	root.add_child(terrain)
	terrain.owner = root
	add_child(root)

	started = Time.get_ticks_msec()
	terrain.data.import_images(
		[_height_image(), _control_image(), _colour_image()],
		Vector3(- YardTerrain.HALF, 0.0, - YardTerrain.HALF), 0.0, 1.0)
	print("[yardbake] imported 3 maps into %d regions in %d ms"
		% [terrain.data.get_region_count(), Time.get_ticks_msec() - started])
	if terrain.data.get_region_count() == 0:
		print("[yardbake] FAILED: the import produced no regions")
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(YardTerrain.DATA_DIR)
	terrain.data.save_directory(YardTerrain.DATA_DIR)
	_write_library_and_scene(root, terrain)
	print("[yardbake] wrote the regions to %s" % YardTerrain.DATA_DIR)
	print("[yardbake] now run: godot --headless --import")
	get_tree().quit(0)


func _write_library_and_scene(root: Node3D, terrain: Terrain3D) -> void:
	var assets:= YardFlora.save_library()
	print("[yardbake] wrote %d plants and %s"
		% [assets.get_mesh_count(), YardFlora.LIBRARY])

	terrain.collision_mask = Cfg.L_WORLD
	terrain.collision_layer = Cfg.L_WORLD


	terrain.collision_mode = Terrain3DCollision.DISABLED
	YardTerrain.build_material(terrain.material)


	var on_disk: Terrain3DAssets = load(YardFlora.LIBRARY)
	terrain.assets = on_disk if on_disk != null else assets


	terrain.data_directory = YardTerrain.DATA_DIR

	var packed:= PackedScene.new()
	if packed.pack(root) != OK:
		print("[yardbake] could not pack the terrain scene")
		return
	DirAccess.make_dir_recursive_absolute(YardTerrain.SCENE.get_base_dir())
	if ResourceSaver.save(packed, YardTerrain.SCENE) != OK:
		print("[yardbake] could not write %s" % YardTerrain.SCENE)
		return
	print("[yardbake] wrote %s" % YardTerrain.SCENE)


func _has_regions() -> bool:
	var dir:= DirAccess.open(YardTerrain.DATA_DIR)
	if dir == null:
		return false
	for f in dir.get_files():
		if f.get_extension() == "res":
			return true
	return false


func _at(x: int, y: int) -> float:
	return _heights [clampi(y, 0, RES - 1) * RES + clampi(x, 0, RES - 1)]


func _world_at(x: int, y: int) -> Vector3:
	return Vector3(- YardTerrain.HALF + x * CELL, 0.0, - YardTerrain.HALF + y * CELL)


func _lerp_at(px: float, py: float) -> float:
	var x:= int(px)
	var y:= int(py)
	var fx:= px - x
	var fy:= py - y
	return lerpf(
		lerpf(_at(x, y), _at(x + 1, y), fx),
		lerpf(_at(x, y + 1), _at(x + 1, y + 1), fx), fy)


func _add_at(px: float, py: float, amount: float) -> void:
	var x:= int(px)
	var y:= int(py)
	var fx:= px - x
	var fy:= py - y
	_bump(x, y, amount * (1.0 - fx) * (1.0 - fy))
	_bump(x + 1, y, amount * fx * (1.0 - fy))
	_bump(x, y + 1, amount * (1.0 - fx) * fy)
	_bump(x + 1, y + 1, amount * fx * fy)


func _bump(x: int, y: int, amount: float) -> void:
	if x < 0 or y < 0 or x >= RES or y >= RES:
		return
	_heights [y * RES + x] += amount


func _raise() -> void:
	var base:= _noise(1177, 1.0 / HILL_PERIOD, 5, 0.45)
	var ridge:= _noise(6301, 1.0 / RIDGE_PERIOD, 4, 0.5)
	var warp_x:= _noise(4409, 1.0 / (HILL_PERIOD * 0.8), 2, 0.5)
	var warp_z:= _noise(8821, 1.0 / (HILL_PERIOD * 0.8), 2, 0.5)
	var mount:= _noise(3313, 1.0 / MOUNT_PERIOD, 5, 0.52)
	var detail:= _noise(7717, 1.0 / MOUNT_DETAIL_PERIOD, 3, 0.5)

	_heights.resize(RES * RES)
	for y in RES:
		for x in RES:
			var w:= _world_at(x, y)


			var sx:= w.x + warp_x.get_noise_2d(w.x, w.z) * WARP
			var sz:= w.z + warp_z.get_noise_2d(w.x, w.z) * WARP
			var h:= base.get_noise_2d(sx, sz) * HILL_H


			var r:= 1.0 - absf(ridge.get_noise_2d(sx, sz))
			var high:= smoothstep(0.0, HILL_H * 0.5, h)
			h += r * r * RIDGE_H * high


			var far:= smoothstep(MOUNT_IN, MOUNT_OUT, Vector2(w.x, w.z).length())
			if far > 0.0:
				var m:= 1.0 - absf(mount.get_noise_2d(sx, sz))
				m = m * m * m
				m += (1.0 - absf(detail.get_noise_2d(sx, sz))) * MOUNT_DETAIL
				h += m * MOUNT_H * far

			_heights [y * RES + x] = h


func _noise(seed_value: int, frequency: float, octaves: int, gain: float) -> FastNoiseLite:
	var n:= FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_value
	n.frequency = frequency
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.05
	n.fractal_gain = gain
	return n


func _erode() -> void:
	var edge:= 2.0
	for _drop in DROPS:
		var px:= _rng.randf_range(edge, RES - edge - 1)
		var py:= _rng.randf_range(edge, RES - edge - 1)
		var dx:= 0.0
		var dy:= 0.0
		var speed:= 1.0
		var water:= 1.0
		var carried:= 0.0

		for _step in DROP_STEPS:
			var x:= int(px)
			var y:= int(py)
			var fx:= px - x
			var fy:= py - y


			var h00:= _at(x, y)
			var h10:= _at(x + 1, y)
			var h01:= _at(x, y + 1)
			var h11:= _at(x + 1, y + 1)
			var gx:= (h10 - h00) * (1.0 - fy) + (h11 - h01) * fy
			var gy:= (h01 - h00) * (1.0 - fx) + (h11 - h10) * fx

			dx = dx * INERTIA - gx * (1.0 - INERTIA)
			dy = dy * INERTIA - gy * (1.0 - INERTIA)
			var length:= sqrt(dx * dx + dy * dy)
			if length < 0.0001:
				break
			dx /= length
			dy /= length

			var was:= _lerp_at(px, py)
			var from_x:= px
			var from_y:= py
			px += dx
			py += dy
			if px < edge or py < edge or px > RES - edge - 1 or py > RES - edge - 1:
				break

			var drop_in_height:= _lerp_at(px, py) - was
			var capacity:= maxf(- drop_in_height, MIN_SLOPE) * speed * water * CAPACITY

			if drop_in_height > 0.0 or carried > capacity:


				var given:= minf(drop_in_height, carried) if drop_in_height > 0.0 else (carried - capacity) * DEPOSIT_RATE
				carried -= given
				_add_at(from_x, from_y, given)
			else:


				var taken:= minf((capacity - carried) * ERODE_RATE, - drop_in_height)
				carried += taken
				_add_at(from_x, from_y, - taken)

			speed = sqrt(maxf(0.0, speed * speed - drop_in_height * GRAVITY))
			water *= 1.0 - EVAPORATE


func _smooth(amount: float) -> void:
	var out:= PackedFloat32Array()
	out.resize(RES * RES)
	for y in RES:
		for x in RES:
			var sum:= 0.0
			for j in range(-1, 2):
				for i in range(-1, 2):
					sum += _at(x + i, y + j)
			out [y * RES + x] = lerpf(_at(x, y), sum / 9.0, amount)
	_heights = out


func _flatten_yard() -> void:
	for y in RES:
		for x in RES:
			var i:= y * RES + x
			_heights [i] = _heights [i] * YardTerrain.relief_at(_world_at(x, y), track_yaw) + YardGround.GROUND_Y


func _height_image() -> Image:
	return Image.create_from_data(RES, RES, false, Image.FORMAT_RF,
		_heights.to_byte_array())


func _farmland_band() -> Vector2:
	var lo:= 1000000000.0
	var hi:= -1000000000.0
	var reach:= int(MOUNT_IN / CELL)
	var mid:= RES / 2
	for y in range(mid - reach, mid + reach):
		for x in range(mid - reach, mid + reach):
			var h:= _at(x, y)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo, hi)


func _slope_at(x: int, y: int) -> float:
	var dx:= (_at(x + 1, y) - _at(x - 1, y)) / (2.0 * CELL)
	var dy:= (_at(x, y + 1) - _at(x, y - 1)) / (2.0 * CELL)
	return sqrt(dx * dx + dy * dy)


func _lane_at(w: Vector3) -> float:
	var u:= w.x * sin(track_yaw) + w.z * cos(track_yaw)
	var v:= w.x * cos(track_yaw) - w.z * sin(track_yaw)
	if u < 0.0:
		return 0.0
	return (1.0 - smoothstep(LANE_HALF, LANE_EDGE, absf(v))) * (1.0 - smoothstep(YardGround.ROAD_END, YardGround.ROAD_END + 60.0, u))


func _control_image() -> Image:
	var patchy:= _noise(2201, 1.0 / 120.0, 3, 0.5)
	var damp:= _noise(5501, 1.0 / 260.0, 2, 0.5)
	var fields:= YardFlora.field_noise()
	var img:= Image.create_empty(RES, RES, false, Image.FORMAT_RF)

	var band:= _farmland_band()
	var lo:= band.x
	var span:= maxf(band.y - band.x, 0.001)

	for y in RES:
		for x in RES:
			var w:= _world_at(x, y)
			var h:= _at(x, y)
			var slope:= _slope_at(x, y)
			var jitter:= patchy.get_noise_2d(w.x, w.z)

			var rock:= smoothstep(ROCK_SLOPE.x, ROCK_SLOPE.y, slope + jitter * 0.06)
			var bare:= smoothstep(DIRT_SLOPE.x, DIRT_SLOPE.y, slope + jitter * 0.05) * (1.0 - rock)


			var wet:= (1.0 - smoothstep(0.2, 0.62, (h - lo) / span)) * (1.0 - smoothstep(0.05, 0.22, slope))


			var crop:= smoothstep(0.02, 0.4, fields.get_noise_2d(w.x, w.z))
			var green:= clampf(wet * 1.15 + crop * 0.85
				+ damp.get_noise_2d(w.x, w.z) * 0.3, 0.0, 1.0) * (1.0 - rock - bare)


			bare = maxf(bare, _lane_at(w))


			var base:= YardFlora.TEX_PASTURE if green > 0.5 else YardFlora.TEX_DRY
			var overlay:= YardFlora.TEX_ROCK if rock >= bare else YardFlora.TEX_TRACK
			var blend:= maxf(rock, bare)

			var ctl:= Terrain3DUtil.enc_base(base) | Terrain3DUtil.enc_overlay(overlay) | Terrain3DUtil.enc_blend(int(clampf(blend, 0.0, 1.0) * 255.0))


			img.set_pixel(x, y, Color(Terrain3DUtil.as_float(ctl), 0.0, 0.0, 1.0))
	return img


func _colour_image() -> Image:
	var patchy:= _noise(2201, 1.0 / 120.0, 3, 0.5)
	var fields:= YardFlora.field_noise()
	var img:= Image.create_empty(RES, RES, false, Image.FORMAT_RGBA8)

	var band:= _farmland_band()
	var lo:= band.x
	var span:= maxf(band.y - band.x, 0.001)

	for y in RES:
		for x in RES:
			var w:= _world_at(x, y)
			var height_t:= clampf((_at(x, y) - lo) / span, 0.0, 1.0)
			var jitter:= patchy.get_noise_2d(w.x, w.z)

			var crop:= fields.get_noise_2d(w.x, w.z)


			var value:= 0.76 + 0.055 * height_t + jitter * 0.025 + crop * 0.06
			img.set_pixel(x, y, Color(
				clampf(value * 1.02, 0.0, 1.0),
				clampf(value, 0.0, 1.0),
				clampf(value * (0.93 - crop * 0.04), 0.0, 1.0),


				0.5))
	return img
