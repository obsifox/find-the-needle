class_name DevPlazaPerfProbe
extends Node


const SETTLE:= 45


const SAMPLE:= 90


const EYE:= Vector3(7.0, 1.7, 33.0)
const AIM:= Vector3(0.0, 44.0, -20.0)

var world: Node3D
var player: Player

var _cam: Camera3D
var _env: Environment
var _sun: DirectionalLight3D
var _voxel: VoxelGI
var _rows: Array [Dictionary] = []


func run() -> void:
	world.block_save = true
	_open_the_taps()
	_hide_the_hud()
	_park_the_camera()
	if not _find_the_switches():
		get_tree().quit(1)
		return


	_say_the_state()

	await _row("everything on (baseline)", func() -> void: pass)
	if _voxel != null:
		await _row("VoxelGI off", func() -> void: _voxel.visible = false)
	await _row("SDFGI off", func() -> void: _env.sdfgi_enabled = false)
	if _voxel != null:
		await _row("both GI off", func() -> void:
			_voxel.visible = false
			_env.sdfgi_enabled = false)
	await _row("SSIL off", func() -> void: _env.ssil_enabled = false)
	await _row("SSAO off", func() -> void: _env.ssao_enabled = false)
	await _row("shadows to 40 m (the shed's cascade)", func() -> void:
		_sun.directional_shadow_max_distance = 40.0)
	await _row("shadows off", func() -> void: _sun.shadow_enabled = false)
	await _row("concrete not triplanar", _flatten_the_concrete)


	await _row("sun baked into the field (static)", func() -> void:
		_sun.light_bake_mode = Light3D.BAKE_STATIC)
	await _row("sun not baked at all (disabled)", func() -> void:
		_sun.light_bake_mode = Light3D.BAKE_DISABLED)


	await _row("only the sun lights the field", _douse_the_other_lights)
	if _voxel != null:
		await _row("VoxelGI at subdiv 64", func() -> void:
			_voxel.subdiv = VoxelGI.SUBDIV_64)


	await _row("nothing is GI dynamic", _settle_the_gi_mode)


	await _row("hay is GI static, field stays", _bake_the_hay)
	await _row("all of the above off", func() -> void:
		if _voxel != null:
			_voxel.visible = false
		_env.sdfgi_enabled = false
		_env.ssil_enabled = false
		_env.ssao_enabled = false
		_sun.directional_shadow_max_distance = 40.0
		_flatten_the_concrete.call())

	_report()
	await _dig_the_pile()
	await _walk_the_site()
	await _the_look_of_it()
	get_tree().quit(0)


const SHOT_DIR:= "user://plazaperf"


const FRAMINGS:= [
	{ "name": "colossus", "eye": Vector3(7.0, 1.7, 33.0), "aim": Vector3(0.0, 44.0, -20.0),
		"note": "at the foot of it, looking up (mostly sky)" },
	{ "name": "shade", "eye": Vector3(-40.0, 1.7, -60.0), "aim": Vector3(-70.0, 18.0, -110.0),
		"note": "in behind the blades, no sun on anything" },
	{ "name": "pile", "eye": Vector3(-26.0, 2.0, 40.0), "aim": Vector3(0.0, 8.0, 0.0),
		"note": "the pile's shaded flank" },
]


func _the_look_of_it() -> void:
	if _voxel == null:
		print("\n[plazaperf] no field to compare against, skipping the framings")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	print("\n--- what the field is worth, per framing ---")
	for f: Dictionary in FRAMINGS:
		var on:= await _shot("%s_voxelgi_on.png" % f ["name"], f, func() -> void: pass)
		var off:= await _shot("%s_voxelgi_off.png" % f ["name"], f,
			func() -> void: _voxel.visible = false)
		_compare(String(f ["name"]), String(f ["note"]), on, off)
	print("[plazaperf] frames in %s" % ProjectSettings.globalize_path(SHOT_DIR))


func _shot(file: String, framing: Dictionary, flip: Callable) -> Image:
	_reset()
	flip.call()
	_cam.global_position = framing ["eye"]
	_cam.look_at(framing ["aim"], Vector3.UP)


	for i in 90:
		await get_tree().process_frame
	var img:= get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [SHOT_DIR, file])
	return img


func _compare(name: String, note: String, on: Image, off: Image) -> void:
	var a:= on.duplicate() as Image
	var b:= off.duplicate() as Image
	a.resize(120, 68, Image.INTERPOLATE_BILINEAR)
	b.resize(120, 68, Image.INTERPOLATE_BILINEAR)
	var total:= 0.0
	var worst:= 0.0
	var lit_on:= 0.0
	for y in a.get_height():
		for x in a.get_width():
			var pa:= a.get_pixel(x, y)
			var pb:= b.get_pixel(x, y)
			var d:= (absf(pa.r - pb.r) + absf(pa.g - pb.g) + absf(pa.b - pb.b)) / 3.0
			total += d
			worst = maxf(worst, d)
			lit_on += (pa.r + pa.g + pa.b) / 3.0
	var n:= float(a.get_width() * a.get_height())
	print("  %-9s %-38s mean %+.1f%%  worst %+.1f%%  (frame sits at %.0f%% grey)"
		% [name, note, 100.0 * total / n, 100.0 * worst, 100.0 * lit_on / n])


const DIG_FRAMES:= 180
const DIG_RADIUS:= 0.9
const DIG_BUDGET:= 160


func _dig_the_pile() -> void:
	var field: Node = world.get("field")
	if field == null:
		print("\n[plazaperf] no pile to dig, skipping the dig row")
		return
	print("\n--- digging, %d frames of scoops into the pile ---" % DIG_FRAMES)
	_reset()
	_cam.global_position = Vector3(0.0, 6.0, 22.0)
	_cam.look_at(Vector3.ZERO, Vector3.UP)
	for i in SETTLE:
		await get_tree().process_frame

	var rid:= get_viewport().get_viewport_rid()
	var gpu:= 0.0
	var worst:= 0.0
	var lifted:= 0
	var started:= Time.get_ticks_usec()
	for i in DIG_FRAMES:
		await get_tree().process_frame


		var a:= float(i) / DIG_FRAMES * TAU
		var x:= cos(a) * 6.0
		var z:= sin(a) * 6.0


		var spot:= Vector3(x, field.height_at(x, z), z)
		lifted += field.take_in_radius(spot, DIG_RADIUS, DIG_BUDGET).size()
		var ms:= RenderingServer.viewport_get_measured_render_time_gpu(rid)
		gpu += ms
		worst = maxf(worst, ms)
	var wall:= float(Time.get_ticks_usec() - started) / 1000.0 / DIG_FRAMES
	print("  %-28s %6.2f ms frame (%3.0f fps)   GPU %5.2f ms, worst %6.2f ms, %d strands lifted"
		% ["digging", wall, 1000.0 / maxf(wall, 0.001), gpu / DIG_FRAMES, worst, lifted])


const WALK_SPEED:= 9.0
const WALK_FRAMES:= 240


func _walk_the_site() -> void:
	print("\n--- walking, %d frames at %.0f m/s ---" % [WALK_FRAMES, WALK_SPEED])
	await _walk_row("everything on", func() -> void: pass)
	await _walk_row("SDFGI off", func() -> void: _env.sdfgi_enabled = false)
	if _voxel != null:
		await _walk_row("SDFGI off, VoxelGI off", func() -> void:
			_env.sdfgi_enabled = false
			_voxel.visible = false)
	await _walk_row("shadows to 40 m", func() -> void:
		_sun.directional_shadow_max_distance = 40.0)
	print("\n[plazaperf] done")


func _walk_row(label: String, flip: Callable) -> void:
	_reset()
	flip.call()
	_cam.global_position = EYE
	for i in SETTLE:
		await get_tree().process_frame

	var rid:= get_viewport().get_viewport_rid()
	var gpu:= 0.0
	var worst:= 0.0
	var started:= Time.get_ticks_usec()
	for i in WALK_FRAMES:
		await get_tree().process_frame


		var t:= float(i) / WALK_FRAMES
		var along:= sin(t * TAU) * WALK_SPEED * WALK_FRAMES / 60.0
		_cam.global_position = EYE + Vector3(0.0, 0.0, - along)
		_cam.look_at(AIM, Vector3.UP)
		var ms:= RenderingServer.viewport_get_measured_render_time_gpu(rid)
		gpu += ms
		worst = maxf(worst, ms)
	var wall:= float(Time.get_ticks_usec() - started) / 1000.0 / WALK_FRAMES
	print("  %-28s %6.2f ms frame (%3.0f fps)   GPU %5.2f ms, worst %6.2f ms"
		% [label, wall, 1000.0 / maxf(wall, 0.001), gpu / WALK_FRAMES, worst])


func _open_the_taps() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(
		get_viewport().get_viewport_rid(), true)


func _hide_the_hud() -> void:
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false
		for kid: Node in node.get_children():
			stack.append(kid)


func _park_the_camera() -> void:
	_cam = Camera3D.new()
	_cam.name = "PerfCamera"
	_cam.far = 2000.0
	world.add_child(_cam)
	_cam.global_position = EYE
	_cam.look_at(AIM, Vector3.UP)
	_cam.current = true
	if player != null:
		player.set_process(false)
		player.set_physics_process(false)


func _find_the_switches() -> bool:
	_env = world.get("env_node").environment if world.get("env_node") != null else null
	_sun = world.get("sun") as DirectionalLight3D
	var plaza: BrutalistPlaza = world.get("plaza")
	if plaza != null and plaza.massing != null:
		_voxel = plaza.massing.get_node_or_null(NodePath("VoxelGI")) as VoxelGI
	if _env == null or _sun == null or plaza == null:
		push_error("plazaperf: no plaza to measure (env %s, sun %s, plaza %s)"
			% [_env, _sun, plaza])
		return false
	if _voxel == null:


		print("plazaperf: no VoxelGI under the massing, skipping its rows")
	return true


func _say_the_state() -> void:
	print("--- plaza perf ---")
	print("quality preset %d, render scale %.2f, msaa %d, taa %s"
		% [int(Cfg.quality), float(Cfg.gfx ["render_scale"]), int(Cfg.gfx ["msaa"]),
			"on" if Cfg.gfx ["taa"] else "off"])
	print("sdfgi %s, ssil %s, ssao %s, shadows %s to %.0f m, VoxelGI %s"
		% ["on" if _env.sdfgi_enabled else "off",
			"on" if _env.ssil_enabled else "off",
			"on" if _env.ssao_enabled else "off",
			"on" if _sun.shadow_enabled else "off",
			_sun.directional_shadow_max_distance,
			"present" if _voxel != null else "MISSING"])
	if _voxel != null:
		print("VoxelGI subdiv %d over %v, sun bake mode %d (0 disabled, 1 static, 2 dynamic)"
			% [int(_voxel.subdiv), _voxel.size, int(_sun.light_bake_mode)])
	print("viewport %s, camera at %v" % [get_viewport().get_visible_rect().size, EYE])


func _row(label: String, flip: Callable) -> void:
	_reset()
	flip.call()
	for i in SETTLE:
		await get_tree().process_frame

	var rid:= get_viewport().get_viewport_rid()
	var gpu:= 0.0
	var cpu:= 0.0
	var started:= Time.get_ticks_usec()
	for i in SAMPLE:
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)


	var wall:= float(Time.get_ticks_usec() - started) / 1000.0 / SAMPLE
	gpu /= SAMPLE
	cpu /= SAMPLE
	_rows.append({ "label": label, "gpu": gpu, "cpu": cpu, "wall": wall })
	print("  %-38s %6.2f ms frame (%3.0f fps)  GPU %5.2f  CPU %5.2f"
		% [label, wall, 1000.0 / maxf(wall, 0.001), gpu, cpu])


func _reset() -> void:
	if _voxel != null:
		_voxel.visible = true
	_env.sdfgi_enabled = bool(Cfg.gfx.get("gi", false))
	_env.ssil_enabled = bool(Cfg.gfx.get("ssil", false))
	_env.ssao_enabled = bool(Cfg.gfx.get("ssao", false))
	_sun.shadow_enabled = bool(Cfg.gfx.get("shadows", true))
	_sun.directional_shadow_max_distance = 700.0
	_sun.light_bake_mode = Light3D.BAKE_DYNAMIC
	if _voxel != null:
		_voxel.subdiv = VoxelGI.SUBDIV_128
	for lamp: Light3D in _put_out:
		if is_instance_valid(lamp):
			lamp.visible = true
	_put_out.clear()
	for gi: GeometryInstance3D in _was_dynamic:
		if is_instance_valid(gi):
			gi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	_was_dynamic.clear()
	var plaza: BrutalistPlaza = world.get("plaza")
	if plaza != null:
		for mi: MeshInstance3D in plaza.masses():
			mi.material_override = null


var _doused:= -1
var _put_out: Array [Light3D] = []
var _douse_the_other_lights:= func() -> void:
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for kid: Node in node.get_children():
			stack.append(kid)
		var lamp:= node as Light3D
		if lamp == null or lamp == _sun or not lamp.visible:
			continue
		lamp.visible = false
		_put_out.append(lamp)
	if _doused < 0:
		_doused = _put_out.size()
		print("    (%d lights out, the sun left standing)" % _doused)


var _settled:= -1
var _was_dynamic: Array [GeometryInstance3D] = []
var _settle_the_gi_mode:= func() -> void:
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for kid: Node in node.get_children():
			stack.append(kid)
		var gi:= node as GeometryInstance3D
		if gi == null or gi.gi_mode != GeometryInstance3D.GI_MODE_DYNAMIC:
			continue
		gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_was_dynamic.append(gi)
	if _settled < 0:
		_settled = _was_dynamic.size()
		print("    (%d dynamically voxelised instances settled)" % _settled)


var _bake_the_hay:= func() -> void:
	var stack: Array [Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for kid: Node in node.get_children():
			stack.append(kid)
		var gi:= node as GeometryInstance3D
		if gi == null or gi.gi_mode != GeometryInstance3D.GI_MODE_DYNAMIC:
			continue
		gi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		_was_dynamic.append(gi)


var _flatten_the_concrete:= func() -> void:
	var plaza: BrutalistPlaza = world.get("plaza")
	if plaza == null:
		return
	var flat:= StandardMaterial3D.new()
	flat.albedo_color = Color(0.62, 0.6, 0.58)
	flat.roughness = 0.85
	for mi: MeshInstance3D in plaza.masses():
		mi.material_override = flat


func _report() -> void:
	if _rows.is_empty():
		return
	var base: float = _rows [0] ["wall"]
	print("\nagainst the baseline, at %.2f ms (%.0f fps if nothing else cost anything):"
		% [base, 1000.0 / maxf(base, 0.001)])
	for i in range(1, _rows.size()):
		var row: Dictionary = _rows [i]
		var saved: float = base - float(row ["wall"])
		print("  %-38s %+7.2f ms  %+5.0f%%"
			% [row ["label"], - saved, -100.0 * saved / base])
	print("\n[plazaperf] done")
