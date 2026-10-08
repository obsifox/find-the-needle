class_name DevDetailCostProbe
extends Node


const OUT_DIR:= "res://captures"
const WARM_FRAMES:= 45
const MEASURE_FRAMES:= 120

var world: Node3D
var player: Player
var field: HayField
var detail: HayDetail

var _cam: Camera3D
var _vp_rid: RID
var _baseline:= 0.0
var _eye:= Vector3.ZERO


func run() -> void:
	world.set("block_save", true)
	world.set("autosave_enabled", false)
	Cfg.perf_scale = 1.0


	Cfg.apply_quality(Cfg.Quality.HIGH)
	Cfg.detail_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)

	_cam = Camera3D.new()
	_cam.fov = 74.0
	_cam.near = 0.01
	_cam.far = 320.0
	world.add_child(_cam)
	_cam.current = true


	var toe: float = Cfg.settled_footprint()
	var eye:= Vector3(toe + 1.4, Player.EYE_HEIGHT, 0.0)
	var look:= Vector3(toe - 5.0, 2.6, 0.0)
	player.global_position = eye - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	_cam.look_at_from_position(eye, look, Vector3.UP)
	field.update_lod(eye)
	_eye = eye

	print("\n=== what the detail ring costs, at High ===")
	print("  pile %s: toe at %.1f m, eye at %.1f m" % [Cfg.pile_size_id, toe, eye.x])
	print("  pool %d strands in %d tiles, %d per cell, radius %.1f m"
		% [detail.pool_size(), detail.tile_count(), detail.strands_per_cell(),
			Cfg.detail_radius])


	detail.reconfigure()
	var t0:= Time.get_ticks_usec()
	var cells:= detail.fill_now(eye)
	var fill_us:= Time.get_ticks_usec() - t0
	print("  full fill: %d cells in %.1f ms, %.0f us per cell, %d strands drawn"
		% [cells, fill_us / 1000.0, float(fill_us) / maxf(1.0, float(cells)),
			detail.drawn_instances()])
	if not _check_hidden_ring():
		get_tree().quit(1)
		return

	await _time("warm-up, discarded")


	var off_sum:= 0.0
	var on_sum:= 0.0
	for pair in 3:
		Cfg.detail_scale = 0.0
		detail.tick(eye)
		var off:= await _time("ring OFF (as it shipped)")
		if pair == 0:
			_baseline = off
			await _shot("detail_off")
		Cfg.detail_scale = 1.0
		detail.tick(eye)
		var on:= await _time("ring ON")
		if pair == 0:
			await _shot("detail_on")
		off_sum += off
		on_sum += on
	var off_mean:= off_sum / 3.0
	var on_mean:= on_sum / 3.0
	print("  PAIRED: off %.2f ms, on %.2f ms, ring costs %+.3f ms (%+.1f%%)"
		% [off_mean, on_mean, on_mean - off_mean,
			100.0 * (on_mean - off_mean) / maxf(off_mean, 0.001)])
	_set_shadows(false)
	await _time("ring ON, casting no shadow")
	_set_shadows(true)
	Cfg.detail_scale = 0.5
	detail.tick(eye)
	await _time("ring ON at half")


	Cfg.detail_scale = 1.0
	player.global_position += Vector3(0.0, 0.0, 2.2)
	var frames:= 0
	var worst:= 0
	var total:= 0
	await get_tree().process_frame
	while detail.pending_cells() > 0 and frames < 900:
		await get_tree().process_frame
		frames += 1
		worst = maxi(worst, detail.last_tick_usec)
		total += detail.last_tick_usec
	print("  one tile sideways: refilled in %d frames, worst tick %.2f ms, mean %.2f ms"
		% [frames, worst / 1000.0, float(total) / maxf(1.0, float(frames)) / 1000.0])
	await get_tree().process_frame
	print("  standing still: tick %.3f ms" % (detail.last_tick_usec / 1000.0))
	get_tree().quit(0)


func _check_hidden_ring() -> bool:
	var buffers: Array [PackedFloat32Array] = []
	for buffer in detail._bufs:
		buffers.append(buffer.duplicate())
	var pool:= detail.drawn_instances()
	var enabled:= HayDetail.hidden_updates_enabled
	HayDetail.hidden_updates_enabled = false
	Cfg.detail_scale = 0.0
	for n in detail.tile_count():
		detail._dirty [n].fill(1)
		detail._dirty_count [n] = HayDetail.CELLS_PER_TILE
		if detail._pending.find(n) < 0:
			detail._pending.append(n)
	var pending:= detail.pending_cells()
	detail.tick(_eye)
	var ok:= detail.drawn_instances() == 0 and detail.pending_cells() == pending
	for n in buffers.size():
		ok = ok and detail._bufs [n] == buffers [n]
	var skipped_us:= detail.last_tick_usec
	HayDetail.hidden_updates_enabled = true
	detail.tick(_eye)
	var legacy_us:= detail.last_tick_usec
	ok = ok and detail.pending_cells() < pending
	HayDetail.hidden_updates_enabled = false
	Cfg.detail_scale = 1.0
	detail.fill_now(_eye)
	ok = ok and detail.pending_cells() == 0 and detail.drawn_instances() == pool
	for n in buffers.size():
		ok = ok and detail._bufs [n] == buffers [n]

	Cfg.detail_scale = 0.0
	var center:= detail._center
	var moved_eye:= _eye + Vector3(detail._tile_m * 2.0, 0.0, 0.0)
	detail.tick(moved_eye)
	ok = ok and detail._center == center and detail.drawn_instances() == 0
	Cfg.detail_scale = 1.0
	detail.fill_now(moved_eye)
	ok = ok and detail._center == detail._tile_of_world(moved_eye.x, moved_eye.z)

	var moved_buffers: Dictionary = { }
	for n in detail.tile_count():
		moved_buffers [detail._tile_of_node [n]] = detail._bufs [n].duplicate()
	detail.reconfigure()
	detail.fill_now(moved_eye)
	for n in detail.tile_count():
		ok = ok and detail._bufs [n] == moved_buffers [detail._tile_of_node [n]]
	detail.fill_now(_eye)
	HayDetail.hidden_updates_enabled = enabled
	print("  hidden ring tick: legacy %d us, paused %d us, resume buffers match=%s"
		% [legacy_us, skipped_us, ok])
	if not ok:
		push_error("detailcost: hidden ring lost queued edits, visibility or seeded resume data")
	return ok


func _set_shadows(on: bool) -> void:
	var mode:= GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for n in detail.get_children():
		if n is GeometryInstance3D:
			n.cast_shadow = mode


func _time(label: String) -> float:
	for i in WARM_FRAMES:
		await get_tree().process_frame
	var total:= 0.0
	var worst:= 0.0
	for i in MEASURE_FRAMES:
		await get_tree().process_frame
		var ms:= RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
		total += ms
		worst = maxf(worst, ms)
	var mean:= total / float(MEASURE_FRAMES)
	var delta:= ""
	if _baseline > 0.0 and not is_equal_approx(mean, _baseline):
		delta = "   %+.1f%%" % (100.0 * (mean - _baseline) / _baseline)
	var fps:= "  (%3.0f fps)" % (1000.0 / maxf(mean, 0.001))
	print("  %-30s gpu %6.2f ms%s%s   ring drawn %d"
		% [label, mean, fps, delta, detail.drawn_instances()])
	return mean


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var path:= "%s/%s_%s.png" % [OUT_DIR, name, Cfg.pile_size_id]
	img.save_png(path)
	print("  wrote %s" % path)
