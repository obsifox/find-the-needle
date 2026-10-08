class_name DevShellBlameProbe
extends Node


const OUT_DIR:= "res://captures"


const BOWL:= Vector3(8.4, 0.0, 0.0)
const RING_R:= 1.0
const RING_CUT:= 1.2
const RING_DROP:= 1.9
const MIDDLE_CUT:= 1.5
const MIDDLE_DROP:= 2.1


const SETTLE_FRAMES:= 120
const SHOT_FRAMES:= 45

var world: Node3D
var player: Player
var field: HayField

var _cam: Camera3D


func run() -> void:


	world.set("block_save", true)
	world.set("autosave_enabled", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Cfg.perf_scale = 1.0
	Cfg.set_quality(Cfg.Quality.HIGH)

	_cam = Camera3D.new()
	_cam.fov = 74.0
	_cam.near = 0.01
	_cam.far = 320.0
	world.add_child(_cam)
	_cam.current = true


	var at:= _deepest_dig()
	if at == Vector3.INF:
		at = BOWL
		at.y = field.height_at(at.x, at.z)
		print("  no dig in this pile; carving the standard bowl at %.1v" % at)
		for k in 16:
			var a:= TAU * float(k) / 16.0
			field.carve_sphere(at + Vector3(cos(a), 0.0, sin(a)) * RING_R,
				RING_CUT, RING_DROP)
		field.carve_sphere(at, MIDDLE_CUT, MIDDLE_DROP)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame

	at.y = field.height_at(at.x, at.z)


	var out:= (Vector3(at.x, 0.0, at.z) - Cfg.PILE_CENTER).normalized()
	var eye: Vector3 = at + out * 1.2 + Vector3(0.0, 1.5, 0.0)
	player.global_position = eye - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	field.update_lod(eye)

	_report(at)

	print("\n=== which layer is it? ===")
	await _shot(eye, at, true, true, "blame_0_both")
	await _shot(eye, at, true, false, "blame_1_shell_only")
	await _shot(eye, at, false, true, "blame_2_crust_only")


	var raised:= Cfg.crust_strands_per_cell * 2
	print("\n=== the same face at double the density (%d) ===" % raised)
	Cfg.crust_strands_per_cell = raised
	field.rebuild_density()
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	field.update_lod(eye)
	_report(at)
	await _shot(eye, at, true, true, "blame_3_raised_both")
	await _shot(eye, at, false, true, "blame_4_raised_crust_only")
	print("  -> %s" % OUT_DIR)
	get_tree().quit(0)


func _deepest_dig() -> Vector3:
	var nc:= Cfg.field_cells()
	var best:= 0.0
	var at:= Vector3.INF
	for j in nc:
		for i in nc:
			var c:= field.cell_center(i, j)
			var dug:= field.dug_depth_at(c.x, c.z)
			if dug > best:
				best = dug
				at = c
	if best <= Cfg.HAY_SHELL_DIG_DEADBAND:
		return Vector3.INF
	print("  deepest dig in this pile is %.2f m at %.1v" % [best, at])
	return at


func _shot(eye: Vector3, look: Vector3, shell: bool, crust: bool,
		name: String) -> void:
	for c in field.chunks:
		var s:= c.get_node_or_null("Shell")
		var k:= c.get_node_or_null("Crust")
		if s != null:
			s.visible = shell
		if k != null:
			k.visible = crust
	_cam.look_at_from_position(eye, look, Vector3.UP)
	for i in SHOT_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, name])
	print("  %s" % name)


func _ask(ci: int, cj: int, c: Vector3, spc: int) -> float:
	var nv:= Cfg.field_verts()
	var base:= cj * nv + ci
	var h00:= field.heights [base]
	var h10:= field.heights [base + 1]
	var h01:= field.heights [base + nv]
	var h11:= field.heights [base + nv + 1]
	var h:= (h00 + h10 + h01 + h11) * 0.25
	var dx:= ((h10 + h11) - (h00 + h01)) * 0.5 / Cfg.CELL
	var dz:= ((h01 + h11) - (h00 + h10)) * 0.5 / Cfg.CELL
	var slope:= sqrt(dx * dx + dz * dz)
	var area_gain:= sqrt(1.0 + slope * slope)
	var avail: float = clampf(minf(Cfg.HAY_SHELL_DEPTH, h * 0.9),
		0.02, Cfg.HAY_SHELL_DEPTH)
	var cropped: float = 1.0 - minf(1.0,
		field.shell_length_limit(c.x, c.z, field.normal_at(c.x, c.z)) / maxf(avail, 0.0001))
	var boost: float = 1.0 + (Cfg.HAY_SHELL_DIG_CRUST - 1.0) * cropped
	return spc * minf(area_gain, 2.2) * boost / 1.35


func _report(at: Vector3) -> void:
	var nc:= Cfg.field_cells()
	var nv:= Cfg.field_verts()
	var spc:= Cfg.crust_strands_per_cell
	var dug_want:= 0.0
	var dug_got:= 0.0
	var dug_crop:= 0.0
	var dug_deep:= 0.0
	var dug_n:= 0
	var capped:= 0
	var open_want:= 0.0
	var open_got:= 0.0
	var open_n:= 0

	for cj in nc:
		for ci in nc:
			var c:= field.cell_center(ci, cj)
			var base:= cj * nv + ci
			var h00:= field.heights [base]
			var h10:= field.heights [base + 1]
			var h01:= field.heights [base + nv]
			var h11:= field.heights [base + nv + 1]
			var h:= (h00 + h10 + h01 + h11) * 0.25
			if h <= 0.03:
				continue
			var avail: float = clampf(minf(Cfg.HAY_SHELL_DEPTH, h * 0.9),
				0.02, Cfg.HAY_SHELL_DEPTH)
			var keep: float = minf(1.0,
				field.shell_length_limit(c.x, c.z, field.normal_at(c.x, c.z)) / maxf(avail, 0.0001))
			var want: float = _ask(ci, cj, c, spc)
			var got: float = clampf(round(want), 1.0, float(spc))

			var dug:= field.dug_depth_at(c.x, c.z)
			if dug > Cfg.HAY_SHELL_DIG_DEADBAND:
				dug_n += 1
				dug_want += want
				dug_got += got
				dug_crop += keep
				dug_deep += dug
				if want > spc:
					capped += 1
			elif dug <= 0.001 and h > 1.0:
				open_n += 1
				open_want += want
				open_got += got

	print("\n=== what the crust was allowed on the dug face ===")
	print("  crust_strands_per_cell (the ceiling) : %d" % spc)
	if open_n > 0:
		print("  open pile   %5d cells   asks %6.1f   gets %6.1f"
			% [open_n, open_want / open_n, open_got / open_n])
	if dug_n == 0:
		print("  no dug cells found")
		return
	print("  dug face    %5d cells   asks %6.1f   gets %6.1f"
		% [dug_n, dug_want / dug_n, dug_got / dug_n])
	print("  %d of %d dug cells (%.0f%%) are asking for more than the ceiling"
		% [capped, dug_n, 100.0 * capped / dug_n])
	print("  the dug face is served %.0f%% of what it asks for"
		% [100.0 * dug_got / maxf(dug_want, 0.0001)])
	if open_n > 0:


		print("  dug asks %.2fx the open pile, and is given %.2fx"
			% [(dug_want / dug_n) / (open_want / open_n),
				(dug_got / dug_n) / (open_got / open_n)])
	print("  mean dig depth %.2f m; shell stack kept %.1f%% of its length"
		% [dug_deep / dug_n, 100.0 * dug_crop / dug_n])
	print("  so the face loses %.1f%% of its shell and is refused the strands"
		% [100.0 - 100.0 * dug_crop / dug_n])
	print("  meant to replace it.")
