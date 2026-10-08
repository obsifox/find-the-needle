class_name DevGpuCostProbe
extends Node


const OUT_DIR:= "res://captures"


const WARM_FRAMES:= 45
const MEASURE_FRAMES:= 120

var world: Node3D
var player: Player
var field: HayField

var _cam: Camera3D
var _vp_rid: RID
var _baseline:= 0.0
var _eye:= Vector3.ZERO


func run() -> void:
	world.set("block_save", true)
	world.set("autosave_enabled", false)
	Cfg.perf_scale = 1.0


	Cfg.apply_quality(Cfg.Quality.HIGH)
	var want: int = int(Cfg.PRESETS [Cfg.Quality.HIGH] ["strands_per_cell"])
	if Cfg.crust_strands_per_cell != want:
		Cfg.crust_strands_per_cell = want
		field.rebuild_density()
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


	var eye:= Vector3(11.6, 1.7, 0.0)
	var look:= Vector3(2.0, 3.4, 0.0)
	player.global_position = eye - Vector3(0.0, Player.EYE_HEIGHT, 0.0)
	player.velocity = Vector3.ZERO
	_cam.look_at_from_position(eye, look, Vector3.UP)
	field.update_lod(eye)
	_eye = eye

	print("\n=== what the pile costs the GPU, at High, 2560x1440 ===")
	print("  drawn crust instances: %d" % field.drawn_instance_count())
	print("  shell layers: %d, per-strand shadow radius: %.0f m"
		% [Cfg.HAY_SHELLS, Cfg.crust_shadow_distance])


	await _time("warm-up, discarded")
	_baseline = await _measure("as it ships", true, Cfg.HAY_SHELLS)
	await _measure("crust shadows off", false, Cfg.HAY_SHELLS)
	await _measure("shells 24 -> 12", true, 12)
	await _measure("shells 24 -> 8", true, 8)
	await _measure("both (no shadows, 8 shells)", false, 8)


	print("  -- taking whole layers away, to find where the time goes --")
	_apply(true, Cfg.HAY_SHELLS)
	await _measure_vis("crust hidden entirely", false, true)
	await _measure_vis("shell hidden entirely", true, false)
	await _measure_vis("pile hidden entirely", false, false)
	_set_vis(true, true)


	print("  -- is the crust geometry-bound? same instances, cheaper mesh --")
	var real_mesh:= StrandFactory.strand_mesh()
	await _measure_mesh("strand as crossed ribbons", StrandFactory.strand_outline_mesh())
	await _measure_mesh("strand as a 6-tri prism", _prism_strand())
	_set_mesh(real_mesh)


	print("  -- thinning the crust instead of cheapening the strand --")
	var lod_was:= Cfg.crust_lod_min
	await _measure_lod("lod_min 0.88 -> 0.70", 0.7)
	await _measure_lod("lod_min 0.88 -> 0.55", 0.55)
	await _measure_lod("lod_min back", lod_was)
	var dens_was:= Cfg.crust_strands_per_cell
	await _measure_density("density 190 -> 150", 150)
	await _measure_density("density 190 -> 120", 120)
	await _measure_density("density back", dens_was)


	print("  -- culling the half of the pile that is behind the pile --")
	var vp:= get_viewport()
	var occ_was: bool = vp.use_occlusion_culling
	vp.use_occlusion_culling = false
	await _time("occlusion culling OFF")
	vp.use_occlusion_culling = occ_was
	await _measure_mesh("crossed ribbons, culling still on", StrandFactory.strand_outline_mesh())
	_set_mesh(real_mesh)

	print("  -- the frame itself, nothing to do with the pile --")
	var scale_was: float = vp.scaling_3d_scale
	var msaa_was: int = vp.msaa_3d
	vp.scaling_3d_scale = 0.85
	await _time("render scale 1.0 -> 0.85")
	vp.scaling_3d_scale = 0.77
	await _time("render scale 1.0 -> 0.77")
	vp.scaling_3d_scale = scale_was
	vp.msaa_3d = Viewport.MSAA_DISABLED
	await _time("msaa 2x -> off")
	vp.msaa_3d = msaa_was

	print("  -- and the post-processing on top of it --")
	var e: Environment = world.get_node("Environment").environment
	await _measure_env("volumetric fog off", e, "volumetric_fog_enabled")
	await _measure_env("ssao off", e, "ssao_enabled")
	await _measure_env("glow off", e, "glow_enabled")


	print("  -- the lighting switches added in the premium pass --")
	await _measure_gfx("bounced light (SDFGI) off", "gi")
	await _measure_gfx("room reflection probe off", "reflect_probe")
	await _measure_gfx("dust motes off", "dust")


	print("  -- the floor, which is not the pile and had never been timed --")
	await _measure_floor_parallax()


	print("  -- what High now ships, measured together rather than added up --")
	vp.msaa_3d = Viewport.MSAA_DISABLED
	Cfg.gfx ["gi"] = false
	world.call("_apply_render_settings")
	await _time("msaa off + SDFGI off (the new High)")
	Cfg.gfx ["gi"] = true
	world.call("_apply_render_settings")
	vp.msaa_3d = msaa_was


	_apply(true, Cfg.HAY_SHELLS)
	_set_vis(true, true)
	_set_mesh(real_mesh)
	Cfg.crust_lod_min = lod_was
	if Cfg.crust_strands_per_cell != dens_was:
		Cfg.crust_strands_per_cell = dens_was
		field.rebuild_density()
	field.update_lod(_eye)
	await _time("CONTROL: as it ships again")
	get_tree().quit(0)


func _apply(shadows: bool, shells: int) -> void:
	var mode:= GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in field.chunks:
		var crust:= c.get_node_or_null("Crust")
		if crust != null:
			crust.cast_shadow = mode
		var shell:= c.get_node_or_null("Shell")
		if shell != null and shell.multimesh != null:
			shell.multimesh.visible_instance_count = shells
	StrandFactory.pile_surface_material().set_shader_parameter("shell_count", shells)


func _set_mesh(m: Mesh) -> void:
	for c in field.chunks:
		var k:= c.get_node_or_null("Crust")
		if k != null and k.multimesh != null:
			k.multimesh.mesh = m


func _measure_lod(label: String, lod_min: float) -> float:
	Cfg.crust_lod_min = lod_min
	field.update_lod(_eye)
	return await _time(label)


func _measure_density(label: String, per_cell: int) -> float:
	Cfg.crust_strands_per_cell = per_cell
	field.rebuild_density()
	field.update_lod(_eye)
	return await _time(label)


func _measure_mesh(label: String, m: Mesh) -> float:
	_set_mesh(m)
	return await _time(label)


func _prism_strand() -> ArrayMesh:
	var t: float = Cfg.STRAND_THICK * 0.5
	var l: float = Cfg.STRAND_LENGTH * 0.5
	var a:= Vector3(0.0, t, 0.0)
	var b:= Vector3(- t, - t * 0.5, 0.0)
	var c:= Vector3(t, - t * 0.5, 0.0)
	var v:= PackedVector3Array()
	var n:= PackedVector3Array()
	var idx:= PackedInt32Array()
	var corners:= [a, b, c]
	for e in 3:
		var p: Vector3 = corners [e]
		var q: Vector3 = corners [(e + 1) % 3]
		var base:= v.size()
		v.append(p + Vector3(0.0, 0.0, - l))
		v.append(q + Vector3(0.0, 0.0, - l))
		v.append(q + Vector3(0.0, 0.0, l))
		v.append(p + Vector3(0.0, 0.0, l))
		var face:= ((p + q) * 0.5).normalized()
		for i in 4:
			n.append(face)
		idx.append_array(PackedInt32Array([base, base + 1, base + 2,
			base, base + 2, base + 3]))
	return _build(v, n, idx)


func _build(v: PackedVector3Array, n: PackedVector3Array,
		idx: PackedInt32Array) -> ArrayMesh:
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = v
	arrays [Mesh.ARRAY_NORMAL] = n
	arrays [Mesh.ARRAY_INDEX] = idx
	var m:= ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, StrandFactory.hay_material())
	return m


func _set_vis(crust: bool, shell: bool) -> void:
	for c in field.chunks:
		var k:= c.get_node_or_null("Crust")
		var sh:= c.get_node_or_null("Shell")
		if k != null:
			k.visible = crust
		if sh != null:
			sh.visible = shell


func _measure_vis(label: String, crust: bool, shell: bool) -> float:
	_set_vis(crust, shell)
	return await _time(label)


func _measure_floor_parallax() -> float:
	var mats:= _floor_materials()
	if mats.is_empty():
		print("  %-30s (no floor material found, skipped)" % "deep parallax off")
		return 0.0
	for m in mats:
		m.heightmap_enabled = false
	var ms:= await _time("floor deep parallax off")
	for m in mats:
		m.heightmap_enabled = true
	for i in 6:
		await get_tree().process_frame
	return ms


func _floor_materials() -> Array [StandardMaterial3D]:
	var out: Array [StandardMaterial3D] = []
	var wh:= world.get_node_or_null("Warehouse")
	if wh == null:
		return out
	var stack: Array [Node] = [wh]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mi:= n as MeshInstance3D
		if mi != null:
			var m:= mi.material_override as StandardMaterial3D
			if m != null and m.heightmap_enabled and not out.has(m):
				out.append(m)
		stack.append_array(n.get_children())
	return out


func _measure_env(label: String, e: Environment, prop: String) -> float:
	var was: bool = e.get(prop)
	e.set(prop, false)
	var ms:= await _time(label)
	e.set(prop, was)
	return ms


func _measure_gfx(label: String, key: String) -> float:
	var was: Variant = Cfg.gfx.get(key)
	Cfg.gfx [key] = false
	world.call("_apply_render_settings")
	var ms:= await _time(label)
	Cfg.gfx [key] = was
	world.call("_apply_render_settings")
	return ms


func _measure(label: String, shadows: bool, shells: int) -> float:
	_apply(shadows, shells)
	return await _time(label)


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
	print("  %-30s gpu %6.2f ms%s%s" % [label, mean, fps, delta])
	return mean
