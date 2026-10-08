class_name DevAvalancheProbe
extends Node


var world: Node3D
var field: HayField
var live: LiveStrandManager
var vfx: AvalancheVfx
var shot_path:= ""
var _shot_camera: Camera3D


const MAX_SETTLE_FRAMES:= 12000
const STRESS_FRAMES:= 240
const VOLUME_TOLERANCE_STRANDS:= 2.0


func _lod_sweep_matches(eye: Vector3) -> int:
	field.update_lod(eye)
	for chunk in field.chunks:
		if chunk._mmi == null:
			continue
		var before:= chunk._lod_visible_k
		var shadow:= chunk._mmi.cast_shadow
		chunk.update_lod(eye)
		if before != chunk._lod_visible_k or shadow != chunk._mmi.cast_shadow:
			return _fail("cached crust detail differs from a full sweep")
	print("[avalanche] cached crust detail matches a full sweep at %s" % eye)
	return 0


func run() -> void:
	field = world.field
	live = world.live
	vfx = world.avalanche_vfx
	field.set_process(false)
	if not shot_path.is_empty():
		_build_shot_camera()
	for _i in 5:
		await get_tree().process_frame

	var failures:= 0
	failures += _fresh_dome_is_stable()
	failures += _vertex_sampling_matches()
	failures += _cached_scatter_matches()
	failures += _lod_sweep_matches(Vector3(0.0, 3.0, -8.0))
	failures += _lod_sweep_matches(Vector3(1000.0, 1000.0, 1000.0))
	var original_min:= Cfg.crust_lod_min
	Cfg.crust_lod_min = 0.61
	failures += _lod_sweep_matches(Vector3(1000.0, 1000.0, 1000.0))
	Cfg.crust_lod_min = original_min
	failures += _lod_sweep_matches(Vector3(0.0, 3.0, -8.0))
	failures += await _pit_collapses()
	var live_before:= live.active_count()


	for z in [-1.6, 0.0, 1.6]:
		var at:= Vector3(5.7, 0.0, z)
		at.y = field.height_at(at.x, at.z) - 0.85
		field.carve_sphere(at, 1.35, 2.6)
	var game_after_carve:= GameState.hay_total
	var volume_after_carve:= field.measure_strands()
	failures += _vertex_sampling_matches()
	failures += _cached_scatter_matches()
	vfx.reset_stats()
	HayChunk.reset_rebuild_profile()

	var settle_us: Array [int] = []
	var flush_us: Array [int] = []
	var worst_visits:= 0
	var frame:= 0
	while field.settling_count() > 0 and frame < MAX_SETTLE_FRAMES:
		var t0:= Time.get_ticks_usec()
		field._settle()
		var t1:= Time.get_ticks_usec()
		field._flush_dirty()
		var t2:= Time.get_ticks_usec()
		settle_us.append(t1 - t0)
		flush_us.append(t2 - t1)
		worst_visits = maxi(worst_visits, field.last_relax_visits())
		if field.last_relax_visits() > Cfg.RELAX_VERTICES_PER_FRAME:
			failures += _fail("relaxation visited %d vertices against a %d budget"
				% [field.last_relax_visits(), Cfg.RELAX_VERTICES_PER_FRAME])
			break
		frame += 1
		await get_tree().process_frame

	var volume_after_settle:= field.measure_strands()
	failures += _lod_sweep_matches(Vector3(0.0, 3.0, -8.0))
	var volume_error:= absf(volume_after_settle - volume_after_carve)
	if field.settling_count() > 0:
		failures += _fail("collapse still has %d queued vertices after %d frames"
			% [field.settling_count(), MAX_SETTLE_FRAMES])


	var nv:= Cfg.field_verts()
	for j in nv:
		for i in nv:
			if field.heights [j * nv + i] > 0.0:
				field._seed_relax(i, j)
	var game_before_stress:= GameState.hay_total
	var volume_before_stress:= field.measure_strands()
	var stress_settle_us: Array [int] = []
	var stress_flush_us: Array [int] = []
	for _stress_frame in STRESS_FRAMES:
		var t0:= Time.get_ticks_usec()
		field._settle()
		var t1:= Time.get_ticks_usec()
		field._flush_dirty()
		var t2:= Time.get_ticks_usec()
		stress_settle_us.append(t1 - t0)
		stress_flush_us.append(t2 - t1)
		worst_visits = maxi(worst_visits, field.last_relax_visits())
		if field.last_relax_visits() > Cfg.RELAX_VERTICES_PER_FRAME:
			failures += _fail("stress wave visited %d vertices against a %d budget"
				% [field.last_relax_visits(), Cfg.RELAX_VERTICES_PER_FRAME])
			break
		await get_tree().process_frame
	var stress_volume_error:= absf(field.measure_strands() - volume_before_stress)
	if live.active_count() != live_before:
		failures += _fail("avalanche created %d rigid bodies"
			% (live.active_count() - live_before))
	if not is_equal_approx(GameState.hay_total, game_after_carve):
		failures += _fail("settling changed hay_total by %.1f"
			% (GameState.hay_total - game_after_carve))
	if volume_error > VOLUME_TOLERANCE_STRANDS:
		failures += _fail("settling changed field volume by %.3f strands"
			% volume_error)
	if not is_equal_approx(GameState.hay_total, game_before_stress):
		failures += _fail("stress wave changed hay_total by %.1f"
			% (GameState.hay_total - game_before_stress))
	if stress_volume_error > VOLUME_TOLERANCE_STRANDS:
		failures += _fail("stress wave changed field volume by %.3f strands"
			% stress_volume_error)
	if vfx.emitted_total <= 0:
		failures += _fail("large collapse requested no GPU particles")
	if vfx.peak_burst > Cfg.AVALANCHE_PARTICLE_BURST:
		failures += _fail("particle burst %d exceeds cap %d"
			% [vfx.peak_burst, Cfg.AVALANCHE_PARTICLE_BURST])

	print("\n=== avalanche regression ===")
	print("  local settle frames : %d" % frame)
	print("  stress queued       : %d after %d bounded frames" % [
		field.settling_count(), STRESS_FRAMES])
	print("  max vertex visits   : %d / %d" % [worst_visits, Cfg.RELAX_VERTICES_PER_FRAME])
	print("  settle p99 / worst  : %.3f / %.3f ms" % [
		_percentile(settle_us, 0.99) / 1000.0, _maximum(settle_us) / 1000.0])
	print("  rebuild p99 / worst : %.3f / %.3f ms" % [
		_percentile(flush_us, 0.99) / 1000.0, _maximum(flush_us) / 1000.0])
	print("  stress settle p99/worst : %.3f / %.3f ms" % [
		_percentile(stress_settle_us, 0.99) / 1000.0,
		_maximum(stress_settle_us) / 1000.0])
	print("  stress rebuild p99/worst: %.3f / %.3f ms" % [
		_percentile(stress_flush_us, 0.99) / 1000.0,
		_maximum(stress_flush_us) / 1000.0])
	var rebuild_n:= maxi(HayChunk.profile_rebuilds, 1)
	print("  chunk avg grid/shape/surface: %.3f / %.3f / %.3f ms (%d rebuilds)" % [
		float(HayChunk.profile_grid_usec) / float(rebuild_n) / 1000.0,
		float(HayChunk.profile_shape_usec) / float(rebuild_n) / 1000.0,
		float(HayChunk.profile_surface_usec) / float(rebuild_n) / 1000.0,
		HayChunk.profile_rebuilds])
	print("  GPU particles sent  : %d (peak burst %d, pool %d)" % [
		vfx.emitted_total, vfx.peak_burst, Cfg.AVALANCHE_PARTICLE_CAP])
	print("  rigid body delta    : %d" % (live.active_count() - live_before))
	print("  field volume error  : %.4f strands" % volume_error)
	print("  stress volume error : %.4f strands" % stress_volume_error)
	print("  result              : %s\n" % ("PASS" if failures == 0
		else "%d FAILURE(S)" % failures))
	if not shot_path.is_empty():
		await _write_shot()
	get_tree().quit(0 if failures == 0 else 1)


func _vertex_sampling_matches() -> int:
	var nv:= Cfg.field_verts()
	var worst:= 0.0
	var samples:= PackedInt32Array([0, 1, nv - 2, nv - 1])
	for i in range(2, nv - 2, 7):
		samples.append(i)
	for j in samples:
		for i in samples:
			var v:= field.vertex_pos(i, j)
			for span in [1, int(Cfg.HAY_SHELL_SMOOTH)]:
				var original:= field.normal_at_scale(v.x, v.z, Cfg.CELL * span)
				worst = maxf(worst, original.distance_to(field.normal_at_vertex(i, j, span)))
			var n:= field.normal_at(v.x, v.z)
			worst = maxf(worst, absf(field.shell_depth_at(v.x, v.z, n)
				- field.shell_depth_at(v.x, v.z, n, field._sample_vertex(i, j))))
			worst = maxf(worst, absf(field.shell_length_limit(v.x, v.z, n)
				- field.shell_length_limit(v.x, v.z, n, field.dug_depth_at_vertex(i, j))))
	print("  vertex sampling error: %.8f" % worst)
	return _fail("grid sampling differs from world sampling by %.8f" % worst) if worst > 1e-05 else 0


func _cached_scatter_matches() -> int:
	var worst:= 0.0
	var checked:= 0
	var fast_us:= 0
	var legacy_us:= 0
	for c in field.chunks:
		var ord_i:= -1
		for i in c._cell_live.size():
			if c._cell_live [i] > 0:
				ord_i = i
				break
		if ord_i < 0:
			continue
		var gc:= c._slot_cells [ord_i]
		var nv:= Cfg.field_verts()
		var ci:= gc % Cfg.field_cells()
		var cj:= gc / Cfg.field_cells()
		var vertex:= cj * nv + ci
		var saved:= field.heights [vertex]
		field.heights [vertex] = maxf(0.0, saved - 0.07)
		c._park_slot(ord_i)
		var started:= Time.get_ticks_usec()
		c._write_cell(ord_i)
		fast_us += Time.get_ticks_usec() - started
		var cached:= c._instance_buffer.duplicate()
		started = Time.get_ticks_usec()
		c._write_cell(ord_i, true)
		legacy_us += Time.get_ticks_usec() - started
		for k in cached.size():
			worst = maxf(worst, absf(cached [k] - c._instance_buffer [k]))
		field.heights [vertex] = saved
		c._write_cell(ord_i)
		c.flush_instance_buffer()
		checked += 1
		if checked >= 12:
			break
	print("  cached scatter error: %.8f (%d cells, fast %d us, full %d us)"
		% [worst, checked, fast_us, legacy_us])
	return _fail("cached scatter differs by %.8f" % worst) if worst > 1e-05 else (_fail("no occupied cells tested") if checked == 0 else 0)


func _fresh_dome_is_stable() -> int:
	var nv:= Cfg.field_verts()
	var worst:= 0.0
	var queued_before:= field.settling_count()
	for j in nv:
		for i in nv:
			var idx:= j * nv + i
			for n: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var ni: int = i + n.x
				var nj: int = j + n.y
				if ni >= nv or nj >= nv:
					continue
				worst = maxf(worst, absf(field.heights [idx]
					- field.heights [nj * nv + ni]))
	var limit: float = tan(deg_to_rad(Cfg.PILE_PREP_ANGLE_DEG)) * Cfg.CELL + HayField.RESEED_MARGIN
	print("  fresh: steepest step %.3f m against %.3f m, queued %d"
		% [worst, limit, queued_before])
	if queued_before > 0:
		return _fail("the fresh dome entered play with %d settling vertices"
			% queued_before)
	if worst > limit + 0.005:
		return _fail("the fresh dome is still too steep: %.3f m against %.3f m"
			% [worst, limit])
	return 0


func _pit_collapses() -> int:
	var at:= _deep_spot()
	if at == Vector3.ZERO:
		return _fail("no deep spot on the pile to bore into")
	var before:= field.height_at(at.x, at.z)


	for _i in 400:
		var c:= Vector3(at.x, field.height_at(at.x, at.z), at.z)
		field.carve_sphere(c, Cfg.RAKE_BITE_RADIUS, Cfg.RAKE_BITE_DROP)
	var bored:= field.height_at(at.x, at.z)
	if bored > before - 0.4:
		return _fail("the bore only took %.2f m, too shallow to be a shaft"
			% (before - bored))

	var frame:= 0
	while field.settling_count() > 0 and frame < MAX_SETTLE_FRAMES:
		field._settle()
		field._flush_dirty()
		frame += 1
		await get_tree().process_frame

	var worst:= _steepest_step_near(at, 4)


	var limit: float = tan(Cfg.ANGLE_OF_REPOSE) * Cfg.CELL + HayField.RESEED_MARGIN
	print("  bore  : %.2f m -> %.2f m, settled in %d frames, steepest step %.3f m"
		% [before, bored, frame, worst])
	if worst > limit + 0.005:
		return _fail("the bore is still walled: %.3f m across one cell against a %.3f m limit"
			% [worst, limit])
	return 0


func _deep_spot() -> Vector3:
	for ring in [4.0, 3.0, 5.0, 2.0, 6.0]:
		for step in 16:
			var a:= TAU * float(step) / 16.0
			var at:= Vector3(cos(a) * ring, 0.0, sin(a) * ring)
			if field.height_at(at.x, at.z) > 1.0:
				return at
	return Vector3.ZERO


func _steepest_step_near(at: Vector3, cells: int) -> float:
	var nv:= Cfg.field_verts()
	var c:= field.cell_at(at.x, at.z)
	var worst:= 0.0
	for j in range(maxi(c.y - cells, 0), mini(c.y + cells + 1, nv)):
		for i in range(maxi(c.x - cells, 0), mini(c.x + cells + 1, nv)):
			var h:= field.heights [j * nv + i]
			for n in 4:
				var ni:= i + (1 if n == 0 else (-1 if n == 1 else 0))
				var nj:= j + (1 if n == 2 else (-1 if n == 3 else 0))
				if ni < 0 or nj < 0 or ni >= nv or nj >= nv:
					continue
				worst = maxf(worst, absf(h - field.heights [nj * nv + ni]))
	return worst


func _build_shot_camera() -> void:
	_shot_camera = Camera3D.new()
	_shot_camera.name = "AvalancheProbeCamera"
	_shot_camera.fov = 48.0
	world.add_child(_shot_camera)
	_shot_camera.global_position = Vector3(9.2, 5.5, 4.8)
	_shot_camera.look_at(Vector3(5.1, 3.6, 0.0), Vector3.UP)
	_shot_camera.current = true
	if world.hud != null:
		world.hud.visible = false


func _write_shot() -> void:
	var absolute:= shot_path
	if shot_path.begins_with("res://") or shot_path.begins_with("user://"):
		absolute = ProjectSettings.globalize_path(shot_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	await RenderingServer.frame_post_draw
	var error:= get_viewport().get_texture().get_image().save_png(absolute)
	if error == OK:
		print("[avalanche] wrote %s" % absolute)
	else:
		push_error("DevAvalancheProbe: could not write %s (%s)" % [absolute, error_string(error)])


func _fail(message: String) -> int:
	print("  FAIL  %s" % message)
	return 1


func _percentile(values: Array [int], fraction: float) -> int:
	if values.is_empty():
		return 0
	var ordered:= values.duplicate()
	ordered.sort()
	var index:= clampi(int(ceil(fraction * float(ordered.size()))) - 1,
		0, ordered.size() - 1)
	return ordered [index]


func _maximum(values: Array [int]) -> int:
	var value:= 0
	for sample in values:
		value = maxi(value, sample)
	return value
