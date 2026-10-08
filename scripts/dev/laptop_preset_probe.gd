class_name DevLaptopPreset
extends Node


var world: Node3D

const SETTLE:= 20

var _bad:= 0


var _reach: Dictionary = { }


func run() -> void:
	for _i in SETTLE:
		await get_tree().process_frame
	var started:= Cfg.quality


	var root:= Node3D.new()
	root.name = "LaptopPresetProbe"
	world.add_child(root)
	var model:= Node3D.new()
	root.add_child(model)
	var box:= MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	model.add_child(box)
	MachineLod.adopt(root, model, "laptop_preset_probe")


	var scanner: Node3D = world.builds.add_scanner(Vector3(8.0, 0.0, 8.0), 0.0)

	var tag:= Label3D.new()
	tag.text = "DROP"
	tag.fixed_size = true
	scanner.add_child(tag)

	for level: int in [Cfg.Quality.POTATO, Cfg.Quality.LOW, Cfg.Quality.MEDIUM,
			Cfg.Quality.HIGH, Cfg.Quality.ULTRA, Cfg.Quality.POTATO, Cfg.Quality.HIGH,
			Cfg.Quality.LOW]:
		await _check(level, box, scanner)


	Cfg.apply_quality(Cfg.Quality.POTATO)
	Cfg.gfx ["glow"] = true
	Cfg._gfx_user ["glow"] = true
	Cfg.apply_quality(Cfg.Quality.HIGH)
	Cfg.apply_quality(Cfg.Quality.POTATO)
	await get_tree().process_frame
	_expect("hand set glow survives the dial", Cfg.gfx ["glow"], true)
	Cfg._gfx_user.erase("glow")
	Cfg.apply_quality(Cfg.Quality.POTATO)
	await get_tree().process_frame
	_expect("glow back to Potato's once the hand set one is gone", Cfg.gfx ["glow"], false)

	Cfg.apply_quality(started)
	root.queue_free()
	if _bad == 0:
		print("[laptoppreset] PASS")
	else:
		print("[laptoppreset] FAIL: %d checks" % _bad)
	get_tree().quit(0 if _bad == 0 else 1)


func _check(level: int, box: MeshInstance3D, scanner: Node3D) -> void:
	Cfg.apply_quality(level as Cfg.Quality)

	await get_tree().process_frame
	await get_tree().process_frame
	var p: Dictionary = Cfg.PRESETS [level]
	var name:= str(p ["name"])
	print("[laptoppreset] %s: distance %.0f m, aniso %d, msaa %d, swap at %.1f m, cell budget %d us"
		% [name, Cfg.machine_distance_metres(),
		int(world.get_viewport().anisotropic_filtering_level),
		int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")),
		box.visibility_range_end, Cfg.cell_update_budget_usec])
	var laptop:= level <= Cfg.Quality.LOW
	_expect(name + " glow", Cfg.gfx ["glow"], level != Cfg.Quality.POTATO)
	_expect(name + " room probe", Cfg.gfx ["reflect_probe"], level != Cfg.Quality.POTATO)
	_expect(name + " dust", Cfg.gfx ["dust"], level != Cfg.Quality.POTATO)
	var env:= (world.get_node("Environment") as WorldEnvironment).environment
	_expect(name + " environment glow", env.glow_enabled, bool(Cfg.gfx ["glow"]))
	var probe = world.get("room_probe")
	if probe != null:
		_expect(name + " probe node", (probe as Node3D).visible, bool(Cfg.gfx ["reflect_probe"]))
	var metres: float = [60.0, 80.0, 80.0, 120.0, 120.0] [level]
	_expect(name + " machine distance", Cfg.machine_distance_metres(), metres)
	var aniso: int = [0, 1] [level] if laptop else int(ProjectSettings.get_setting(
		"rendering/textures/default_filters/anisotropic_filtering_level"))
	_expect(name + " anisotropic filtering",
		int(world.get_viewport().anisotropic_filtering_level), aniso)
	_expect(name + " project msaa follows the viewport",
		int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")),
		int(world.get_viewport().msaa_3d))
	var scale: float = [0.5, 0.75] [level] if laptop else 1.0
	_expect(name + " cell budget", Cfg.cell_update_budget_usec,
		int(Cfg.CELL_UPDATE_BUDGET_USEC * scale))
	_expect(name + " chunk budget", Cfg.chunk_rebuild_budget_usec,
		int(Cfg.CHUNK_REBUILD_BUDGET_USEC * scale))
	_expect(name + " relax budget", Cfg.relax_update_budget_usec,
		int(Cfg.RELAX_UPDATE_BUDGET_USEC * scale))
	var base: float = [15.0, 22.0] [level] if laptop else MachineLod.SWAP_BASE
	_expect(name + " swap floor", MachineLod.swap_base(), base)
	var gate:= base + box.mesh.get_aabb().size.length() * 0.5 * MachineLod.SIZE_GAIN
	_expect(name + " near mesh range", snappedf(box.visibility_range_end, 0.001),
		snappedf(gate, 0.001))
	var far:= box.get_parent().get_node_or_null("FarLod") as MeshInstance3D
	if far == null:
		_expect(name + " far mesh built", false, true)
	else:
		_expect(name + " far mesh range", snappedf(far.visibility_range_begin, 0.001),
			snappedf(gate, 0.001))
	_check_placed(name, scanner, base)


func _check_placed(name: String, scanner: Node3D, base: float) -> void:
	var parts:= 0
	var signs:= 0
	var sign_metres:= float(Cfg.preset().get("sign_distance", 0.0))
	for n: Node in scanner.find_children("*", "GeometryInstance3D", true, false):
		var g:= n as GeometryInstance3D
		if g.has_meta(MachineLod.LOD_END_META):
			parts += 1
			var lod_end:= float(g.get_meta(MachineLod.LOD_END_META))
			if not _reach.has(g):
				_reach [g] = lod_end - base
			_expect(name + " scanner part swap moved with the floor",
				snappedf(lod_end - base, 0.001), snappedf(float(_reach [g]), 0.001))
			if g.visibility_range_end <= 0.0 or g.visibility_range_end > lod_end + 0.001:
				_expect(name + " scanner part drawn to its swap and no further",
					g.visibility_range_end, lod_end)
		elif g is Label3D and sign_metres > 0.0 and g.is_visible_in_tree() and not (g as Label3D).fixed_size:
			signs += 1
			var r:= g.get_aabb().size.length() * 0.5
			if g.visibility_range_end <= 0.0 or g.visibility_range_end > sign_metres + r + 0.001:
				_expect(name + " scanner sign cut at the sign distance",
					g.visibility_range_end, sign_metres + r)
		elif g is Label3D and (g as Label3D).fixed_size:


			var r:= g.get_aabb().size.length() * 0.5
			_expect(name + " fixed size tag keeps the machine distance",
				snappedf(g.visibility_range_end, 0.001),
				snappedf(Cfg.machine_distance_metres() + r, 0.001))
	if parts == 0:
		_expect(name + " scanner has swapped parts", parts > 0, true)
	print("[laptoppreset]   scanner: %d swapped parts, %d signs checked" % [parts, signs])


func _expect(what: String, got: Variant, want: Variant) -> void:
	var same: bool = (is_equal_approx(float(got), float(want))
		if typeof(want) == TYPE_FLOAT else got == want)
	if same:
		return
	_bad += 1
	print("  FAIL  %s: %s, want %s" % [what, got, want])
