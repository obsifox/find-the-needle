class_name CrustCells
extends RefCounted


static var extent:= 15.0
static var cell:= 0.25
static var run_seed:= 0
static var crust_depth:= 0.0
static var shell_depth:= 0.0
static var shell_grade:= 0.0
static var shell_reach:= 0.0
static var dig_deadband:= 0.0
static var dig_k:= 0.0
static var dig_floor:= 0.0
static var dig_crust:= 0.0
static var steep_lo:= 0.0
static var steep_hi:= 0.0
static var steep_floor:= 0.0
static var len_min:= 0.0
static var len_max:= 0.0
static var len_mid:= 0.0
static var col_dark:= Color()
static var col_light:= Color()


static func capture() -> void:
	extent = Cfg.FIELD_EXTENT
	cell = Cfg.CELL
	run_seed = GameState.run_seed
	crust_depth = Cfg.CRUST_DEPTH
	shell_depth = Cfg.HAY_SHELL_DEPTH
	shell_grade = Cfg.HAY_SHELL_GRADE
	shell_reach = Cfg.HAY_SHELL_REACH
	dig_deadband = Cfg.HAY_SHELL_DIG_DEADBAND
	dig_k = Cfg.HAY_SHELL_DIG_K
	dig_floor = Cfg.HAY_SHELL_DIG_FLOOR
	dig_crust = Cfg.HAY_SHELL_DIG_CRUST
	steep_lo = Cfg.HAY_SHELL_STEEP_LO
	steep_hi = Cfg.HAY_SHELL_STEEP_HI
	steep_floor = Cfg.HAY_SHELL_STEEP_FLOOR
	len_min = Cfg.STRAND_LEN_MIN
	len_max = Cfg.STRAND_LEN_MAX
	len_mid = Cfg.STRAND_LENGTH
	col_dark = Cfg.COL_HAY_DARK
	col_light = Cfg.COL_HAY_LIGHT


var heights:= PackedFloat32Array()
var dome:= PackedFloat32Array()
var nv:= 0
var nc:= 0


var slot_cells:= PackedInt32Array()
var cell_live:= PackedInt32Array()
var cell_coloured:= PackedInt32Array()
var instance_buffer:= PackedFloat32Array()
var scatter_samples:= PackedFloat32Array()
var strands_per_cell:= 1

var dirty:= false


var ords:= PackedInt32Array()

var budget_us:= 0


var done:= 0
var usec:= 0

var rng:= RandomNumberGenerator.new()


func write_cells() -> void:
	var t:= Time.get_ticks_usec()
	done = 0
	for ord_i in ords:
		write_cell(ord_i, false)
		done += 1
		if Time.get_ticks_usec() - t >= budget_us:
			break
	usec = Time.get_ticks_usec() - t


func write_cell(ord_i: int, legacy: bool) -> void:
	var gc:= slot_cells [ord_i]
	var ci:= gc % nc
	var cj:= gc / nc
	var n_cells:= slot_cells.size()
	var was_live:= cell_live [ord_i]

	var base_i:= cj * nv + ci
	var h00:= heights [base_i]
	var h10:= heights [base_i + 1]
	var h01:= heights [base_i + nv]
	var h11:= heights [base_i + nv + 1]
	var h:= (h00 + h10 + h01 + h11) * 0.25

	if h <= 0.03:
		for k in was_live:
			_park_slot(k * n_cells + ord_i)
		cell_live [ord_i] = 0
		return

	var dx:= ((h10 + h11) - (h00 + h01)) * 0.5 / cell
	var dz:= ((h01 + h11) - (h00 + h10)) * 0.5 / cell
	var slope:= sqrt(dx * dx + dz * dz)
	var area_gain:= sqrt(1.0 + slope * slope)
	var cell_c:= Vector3(- extent + (ci + 0.5) * cell, 0.0, - extent + (cj + 0.5) * cell)
	var avail: float = _shell_depth_at(cell_c.x, cell_c.z, Vector3(- dx, 1.0, - dz))
	var cropped: float = 1.0 - minf(1.0,
		_shell_length_limit(cell_c.x, cell_c.z, Vector3(- dx, 1.0, - dz).normalized()) / maxf(avail, 0.0001))
	var dig_boost: float = 1.0 + (dig_crust - 1.0) * cropped
	var count:= clampi(int(round(strands_per_cell * minf(area_gain, 2.2) * dig_boost / 1.35)),
		1, strands_per_cell)

	var cx: float = - extent + ci * cell
	var cz: float = - extent + cj * cell
	var depth: float = minf(crust_depth, h)
	var coloured:= cell_coloured [ord_i]

	if count > coloured or legacy:
		rng.seed = hash(Vector2i(ci, cj)) ^ (run_seed * 2654435761)
		for k in count:
			var slot:= k * n_cells + ord_i
			var u:= rng.randf()
			var v:= rng.randf()
			var t:= rng.randf()
			var fraction:= t * t
			var jitter:= rng.randf_range(-0.01, 0.05)
			var basis:= _strand_basis()
			var tint:= _tint()
			if k >= coloured or legacy:
				var o:= slot * 4
				scatter_samples [o] = u
				scatter_samples [o + 1] = v
				scatter_samples [o + 2] = fraction
				scatter_samples [o + 3] = jitter
				var surf:= lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)
				_set_transform(slot, Transform3D(basis,
					Vector3(cx + u * cell, surf - fraction * depth + jitter,
						cz + v * cell)))
				_set_color(slot, tint)
	if not legacy:
		for k in count:
			var slot:= k * n_cells + ord_i
			var o:= slot * 4
			var u:= scatter_samples [o]
			var v:= scatter_samples [o + 1]
			var surf:= lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)
			instance_buffer [slot * HayChunk.INSTANCE_STRIDE + 7] = surf - scatter_samples [o + 2] * depth + scatter_samples [o + 3]
		dirty = true

	for k in range(count, was_live):
		_park_slot(k * n_cells + ord_i)

	cell_live [ord_i] = count
	if count > coloured:
		cell_coloured [ord_i] = count


func _park_slot(slot: int) -> void:
	instance_buffer [slot * HayChunk.INSTANCE_STRIDE + 7] = HayChunk.PARK_Y
	dirty = true


func _set_transform(slot: int, xf: Transform3D) -> void:
	var o:= slot * HayChunk.INSTANCE_STRIDE
	var b:= xf.basis
	instance_buffer [o] = b.x.x
	instance_buffer [o + 1] = b.y.x
	instance_buffer [o + 2] = b.z.x
	instance_buffer [o + 3] = xf.origin.x
	instance_buffer [o + 4] = b.x.y
	instance_buffer [o + 5] = b.y.y
	instance_buffer [o + 6] = b.z.y
	instance_buffer [o + 7] = xf.origin.y
	instance_buffer [o + 8] = b.x.z
	instance_buffer [o + 9] = b.y.z
	instance_buffer [o + 10] = b.z.z
	instance_buffer [o + 11] = xf.origin.z
	dirty = true


func _set_color(slot: int, c: Color) -> void:
	var o:= slot * HayChunk.INSTANCE_STRIDE + 12
	instance_buffer [o] = c.r
	instance_buffer [o + 1] = c.g
	instance_buffer [o + 2] = c.b
	instance_buffer [o + 3] = c.a
	dirty = true


func _strand_basis() -> Basis:
	var dir:= Vector3(
		rng.randfn(0.0, 1.0),
		rng.randfn(0.0, 1.0) * (1.0 - 0.75),
		rng.randfn(0.0, 1.0)
	)
	if dir.length_squared() < 1e-06:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var up:= Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var x_axis:= up.cross(dir).normalized()
	var y_axis:= dir.cross(x_axis).normalized()
	var spin:= rng.randf_range(0.0, TAU)
	var b:= Basis(x_axis, y_axis, dir).rotated(dir, spin)
	b.z *= rng.randf_range(len_min, len_max) / len_mid
	return b


func _tint() -> Color:
	var t:= rng.randf()
	t = pow(t, 1.45)
	var c:= col_dark.lerp(col_light, t)
	var v:= rng.randf_range(0.78, 1.2)
	var hue:= rng.randf_range(-1.0, 1.0)
	return Color(c.r * v * (1.0 + hue * 0.07),
			c.g * v,
			c.b * v * (1.0 - hue * 0.14), 1.0)


func _height_at(wx: float, wz: float) -> float:
	var fx:= (wx + extent) / cell
	var fz:= (wz + extent) / cell
	var i:= int(floor(fx))
	var j:= int(floor(fz))
	if i < 0 or j < 0 or i >= nv - 1 or j >= nv - 1:
		return 0.0
	var tx:= fx - i
	var tz:= fz - j
	var h00:= heights [j * nv + i]
	var h10:= heights [j * nv + i + 1]
	var h01:= heights [(j + 1) * nv + i]
	var h11:= heights [(j + 1) * nv + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _dug_depth_at(wx: float, wz: float) -> float:
	if dome.size() != heights.size():
		return 0.0
	var fx:= (wx + extent) / cell
	var fz:= (wz + extent) / cell
	var i:= int(floor(fx))
	var j:= int(floor(fz))
	if i < 0 or j < 0 or i >= nv - 1 or j >= nv - 1:
		return 0.0
	var tx:= fx - i
	var tz:= fz - j
	var d00:= dome [j * nv + i] - heights [j * nv + i]
	var d10:= dome [j * nv + i + 1] - heights [j * nv + i + 1]
	var d01:= dome [(j + 1) * nv + i] - heights [(j + 1) * nv + i]
	var d11:= dome [(j + 1) * nv + i + 1] - heights [(j + 1) * nv + i + 1]
	return maxf(0.0, lerpf(lerpf(d00, d10, tx), lerpf(d01, d11, tx), tz))


func _shell_depth_at(wx: float, wz: float, n: Vector3) -> float:
	var h:= _height_at(wx, wz)
	var d: float = minf(shell_depth, h * 0.9)
	var down:= Vector2(n.x, n.z)
	if d <= 0.02 or down.length_squared() < 1e-08:
		return clampf(d, 0.02, shell_depth)
	down = down.normalized()
	var step:= cell
	while step <= shell_reach:
		if step * shell_grade >= d:
			break
		d = minf(d, _height_at(wx + down.x * step, wz + down.y * step) * 0.9
			+ step * shell_grade)
		step += cell
	return clampf(d, 0.02, shell_depth)


func _shell_length_limit(wx: float, wz: float, n: Vector3) -> float:
	var depth:= _dug_depth_at(wx, wz)
	var dug:= maxf(0.0, depth - dig_deadband)
	var by_dig:= clampf(1.0 - dug * dig_k, dig_floor, 1.0)
	var slope:= Vector2(n.x, n.z).length() / maxf(n.y, 0.0001)
	var by_slope:= clampf(1.0 - (slope - steep_lo)
		/ maxf(steep_hi - steep_lo, 0.0001),
		steep_floor, 1.0)
	return shell_depth * minf(by_dig, by_slope)


class Batch extends RefCounted:
	var jobs: Array [CrustCells] = []

	func run(i: int) -> void:
		jobs [i].write_cells()
