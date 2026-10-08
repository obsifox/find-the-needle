extends RefCounted


const BASELINE_EVERY:= 10

const FILL_DEFAULT:= 5000

const FILL_KINDS:= [
	[BeltRun.Kind.WAD, "wads"],
	[BeltRun.Kind.BALE, "bales"],
	[BeltRun.Kind.FOILED_BALE, "foiled bales"],
	[BeltRun.Kind.BRICK, "bricks"],
]

var p: Node
var world: Node3D


var _undo: Array [Callable] = []
var _since_base:= 0

var _section:= { }
var _now_section:= ""


func run(probe: Node) -> void:
	p = probe
	world = p.world
	var ua:= OS.get_cmdline_user_args()
	_say_cargo()
	await _cargo_rows()
	await _building_rows()
	await _scene_rows()
	await _graphics_rows()
	await _together_rows()
	await _tick_rows()
	var at:= ua.find("--fill")
	if at >= 0:
		var n:= FILL_DEFAULT
		if at + 1 < ua.size() and ua [at + 1].is_valid_int():
			n = int(ua [at + 1])
		await _fill_rows(n)
	await _physics_rows()
	await _base()
	_report()


func _r(label: String, flip: Callable) -> void:
	if _since_base >= BASELINE_EVERY:
		await _base()
	_section [label] = _now_section
	await p._row(label, func() -> void:
		_undo_all()
		flip.call())
	_since_base += 1


func _base() -> void:
	_since_base = 0
	await p._row("everything on (baseline)", func() -> void: _undo_all())


func _undo_all() -> void:
	for i in range(_undo.size() - 1, -1, -1):
		_undo [i].call()
	_undo.clear()


func _put(obj: Object, prop: String, value: Variant) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	var was: Variant = obj.get(prop)
	obj.set(prop, value)
	_undo.append(func() -> void:
		if is_instance_valid(obj):
			obj.set(prop, was))


func _hide(nodes: Array) -> void:
	p._hide_all(nodes)


func _silence(nodes: Array) -> void:
	p._silence_all(nodes)


func _all_of(type: String) -> Array:
	var out: Array = []
	var stack: Array [Node] = [p.get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for kid: Node in node.get_children():
			stack.append(kid)
		if node.is_class(type) and node != p:
			out.append(node)
	return out


func _paths() -> Array [BeltPath]:
	var out: Array [BeltPath] = []
	for path in BeltPath._live:
		if is_instance_valid(path):
			out.append(path)
	return out


func _cargo_by_kind() -> Dictionary:
	var out:= { }
	for path in _paths():
		var run: BeltRun = path.run
		for i in range(run.first(), run.first() + run.count()):
			var k: int = run._kind [i]
			out [k] = int(out.get(k, 0)) + 1
	return out


func _kind_name(k: int) -> String:
	return BeltRun.ITEM_IDS [k] if k >= 0 and k < BeltRun.ITEM_IDS.size() else str(k)


func _say_cargo() -> void:
	var by:= _cargo_by_kind()
	var total:= 0
	var parts: Array [String] = []
	for k: int in by:
		total += int(by [k])
		parts.append("%s %d" % [_kind_name(k), by [k]])
	print("HUNT: %d belt paths, %d records aboard (%s)" % [_paths().size(), total, ", ".join(parts)])


func _cargo_bins(kind: int) -> Array:
	var out: Array = []
	var batch:= BeltRunBatch.instance
	if batch == null:
		return out
	for rd in batch._runs:
		for b in rd.bins.values():
			if (kind < 0 or b.kind == kind) and is_instance_valid(b.node):
				out.append(b.node)
	return out


func _cargo_rows() -> void:
	_now_section = "belt cargo"
	var by:= _cargo_by_kind()
	await _r("belt cargo: every record hidden", func() -> void: _hide(_cargo_bins(-1)))
	for k: int in by:
		var kind:= k
		await _r("belt cargo: %s hidden (%d)" % [_kind_name(k), by [k]], func() -> void:
			_hide(_cargo_bins(kind)))
	await _r("belt cargo: record drawer stopped", func() -> void:
		if BeltRunBatch.instance != null:
			_put(BeltRunBatch.instance, "process_mode", Node.PROCESS_MODE_DISABLED))
	await _r("belt cargo: body rider drawer stopped", func() -> void:
		if BeltItemBatch.instance != null:
			_put(BeltItemBatch.instance, "process_mode", Node.PROCESS_MODE_DISABLED))
	await _r("belt frames: batched belt meshes hidden", func() -> void:
		if BeltBatch.instance != null:
			_hide([BeltBatch.instance]))
	await _r("belts: every path's tick silenced", func() -> void:
		_silence(_paths()))
	await _r("belts: everything drawn hidden", func() -> void:
		_hide(p._belt_nodes())
		for inst in [BeltBatch.instance, BeltRunBatch.instance, BeltItemBatch.instance]:
			if inst != null:
				_hide([inst]))
	await _r("belts: hidden AND silenced", func() -> void:
		_hide(p._belt_nodes())
		for inst in [BeltBatch.instance, BeltRunBatch.instance, BeltItemBatch.instance]:
			if inst != null:
				_hide([inst])
		_silence(_paths())
		_silence(p._belt_nodes()))


func _by_class() -> Dictionary:
	var out:= { }
	for b: Node3D in world.builds.all_buildings():
		if not is_instance_valid(b):
			continue
		var key:= b.get_class()
		var sc:= b.get_script() as Script
		if sc != null:
			key = sc.get_global_name() if sc.get_global_name() != &"" else sc.resource_path.get_file().get_basename()
		if not out.has(key):
			out [key] = []
		(out [key] as Array).append(b)
	return out


func _building_rows() -> void:
	_now_section = "buildings"
	var classes:= _by_class()
	var keys: Array = classes.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return (classes [a] as Array).size() > (classes [b] as Array).size())
	for key: String in keys:
		var nodes: Array = classes [key]
		await _r("%s hidden (%d)" % [key, nodes.size()], func() -> void: _hide(nodes))
		await _r("%s silenced (%d)" % [key, nodes.size()], func() -> void: _silence(nodes))


func _scene_rows() -> void:
	_now_section = "scene"
	var env: Environment = p._env
	await _r("sky: flat colour instead of the cloud sky", func() -> void:
		_put(env, "background_mode", Environment.BG_COLOR)
		_put(world, "_sky_mat", null))
	await _r("sun off", func() -> void: _put(world.sun, "visible", false))
	if world.fill != null:
		await _r("fill light off", func() -> void: _put(world.fill, "visible", false))
	var lamps:= _all_of("OmniLight3D") + _all_of("SpotLight3D")
	await _r("every omni and spot light off (%d)" % lamps.size(), func() -> void: _hide(lamps))
	var probes:= _all_of("ReflectionProbe")
	if not probes.is_empty():
		await _r("reflection probes off (%d)" % probes.size(), func() -> void: _hide(probes))
	var parts:= _all_of("GPUParticles3D") + _all_of("CPUParticles3D")
	if not parts.is_empty():
		await _r("every particle system off (%d)" % parts.size(), func() -> void: _hide(parts))
	var labels:= _all_of("Label3D")
	if not labels.is_empty():
		await _r("every 3D label hidden (%d)" % labels.size(), func() -> void: _hide(labels))
	var decals:= _all_of("Decal")
	if not decals.is_empty():
		await _r("every decal hidden (%d)" % decals.size(), func() -> void: _hide(decals))
	var mixers:= _all_of("AnimationMixer")
	await _r("every animation stopped (%d players)" % mixers.size(), func() -> void:
		for m in mixers:
			_put(m, "active", false))
	var sounds:= _all_of("AudioStreamPlayer") + _all_of("AudioStreamPlayer3D")
	await _r("every sound paused (%d players)" % sounds.size(), func() -> void:
		for s in sounds:
			_put(s, "stream_paused", true))

	for name: String in ["field", "detail", "live", "terrain", "warehouse", "plaza",
			"wheat_cull", "dust", "stand", "shop", "truck", "bay_door", "shop_board",
			"rank_board", "delivery_board", "needle_glints", "landing_zone",
			"avalanche_vfx", "belt_flip_vfx"]:
		var node:= world.get(name) as Node
		if node == null or not is_instance_valid(node):
			continue
		var n3:= node as Node3D
		if n3 != null:
			await _r("%s hidden" % name, func() -> void: _hide([n3]))
		await _r("%s silenced" % name, func() -> void: _silence([node]))

	await _r("props hidden (%d)" % world.props.items.size(), func() -> void:
		_hide(p._prop_nodes()))
	await _r("props asleep", func() -> void: p._sleep_the_props())
	await _r("world's own tick off (LOD walks, clouds, belt sweep)", func() -> void:
		_put(world, "process_mode", Node.PROCESS_MODE_DISABLED)

		for kid in world.get_children():
			if kid.process_mode == Node.PROCESS_MODE_INHERIT:
				_put(kid, "process_mode", Node.PROCESS_MODE_ALWAYS))
	await _r("player silenced", func() -> void: _silence([world.player]))
	await _r("HUD and every menu layer hidden", func() -> void:
		for layer in _all_of("CanvasLayer"):
			_put(layer, "visible", false))


func _graphics_rows() -> void:
	_now_section = "graphics"
	var env: Environment = p._env
	var sun: DirectionalLight3D = p._sun
	var vp: Viewport = p.get_viewport()
	await _r("SDFGI off", func() -> void: _put(env, "sdfgi_enabled", false))
	await _r("SSIL off", func() -> void: _put(env, "ssil_enabled", false))
	await _r("SSAO off", func() -> void: _put(env, "ssao_enabled", false))
	await _r("SSR off", func() -> void: _put(env, "ssr_enabled", false))
	await _r("glow off", func() -> void: _put(env, "glow_enabled", false))
	await _r("fog off", func() -> void: _put(env, "fog_enabled", false))
	await _r("volumetric fog off", func() -> void: _put(env, "volumetric_fog_enabled", false))
	await _r("TAA off", func() -> void: _put(vp, "use_taa", false))
	await _r("MSAA off", func() -> void: _put(vp, "msaa_3d", Viewport.MSAA_DISABLED))
	await _r("FXAA / SMAA off", func() -> void:
		_put(vp, "screen_space_aa", Viewport.SCREEN_SPACE_AA_DISABLED))
	await _r("render scale 0.5 (is it the GPU?)", func() -> void:
		_put(vp, "scaling_3d_scale", 0.5))
	await _r("shadows off", func() -> void: _put(sun, "shadow_enabled", false))
	await _r("shadows 2 cascades", func() -> void:
		_put(sun, "directional_shadow_mode", DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS))
	await _r("shadows to 40 m", func() -> void:
		_put(sun, "directional_shadow_max_distance", 40.0))
	await _r("nothing built casts a shadow", func() -> void:
		p._uncast(p._prop_nodes())
		p._uncast(p._belt_nodes())
		p._uncast(p._machine_nodes())
		p._uncast(p._pole_nodes())
		p._uncast(_cargo_bins(-1))
		if BeltBatch.instance != null:
			p._uncast([BeltBatch.instance]))
	await _r("every graphics switch off", func() -> void:
		for key in ["sdfgi_enabled", "ssil_enabled", "ssao_enabled", "ssr_enabled",
				"glow_enabled", "fog_enabled", "volumetric_fog_enabled"]:
			_put(env, key, false)
		_put(sun, "shadow_enabled", false)
		_put(vp, "use_taa", false)
		_put(vp, "msaa_3d", Viewport.MSAA_DISABLED))


func _together_rows() -> void:
	_now_section = "together"
	await _r("nothing built is drawn", func() -> void:
		_hide(p._prop_nodes())
		_hide(p._belt_nodes())
		_hide(p._machine_nodes())
		_hide(p._pole_nodes())
		for inst in [BeltBatch.instance, BeltRunBatch.instance, BeltItemBatch.instance]:
			if inst != null:
				_hide([inst]))
	await _r("nothing built ticks", func() -> void:
		_silence(world.builds.all_buildings())
		_silence(_paths())
		p._sleep_the_props())
	await _r("nothing built is drawn OR ticks", func() -> void:
		_hide(p._prop_nodes())
		_hide(world.builds.all_buildings())
		for inst in [BeltBatch.instance, BeltRunBatch.instance, BeltItemBatch.instance]:
			if inst != null:
				_hide([inst])
		_silence(world.builds.all_buildings())
		_silence(_paths())
		p._sleep_the_props())
	await _r("empty yard: nothing built, no pile, no sky extras", func() -> void:
		_hide(p._prop_nodes())
		_hide(world.builds.all_buildings())
		for inst in [BeltBatch.instance, BeltRunBatch.instance, BeltItemBatch.instance]:
			if inst != null:
				_hide([inst])
		_silence(world.builds.all_buildings())
		_silence(_paths())
		p._sleep_the_props()
		for name: String in ["field", "detail", "live"]:
			var node:= world.get(name) as Node
			if node != null:
				_silence([node])
				if node is Node3D:
					_hide([node]))


func _tick_rows() -> void:
	_now_section = "ticking scripts"
	var by_key: Dictionary = { }
	var stack: Array [Node] = [p.get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for kid: Node in node.get_children():
			stack.append(kid)
		if node == p or not (node.is_processing() or node.is_physics_processing()):
			continue
		var key: String = node.get_class()
		var script:= node.get_script() as Script
		if script != null and script.resource_path != "":
			key = script.resource_path.get_file().get_basename()
		if not by_key.has(key):
			by_key [key] = []
		(by_key [key] as Array).append(node)
	var keys: Array = by_key.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return (by_key [a] as Array).size() > (by_key [b] as Array).size())
	for key: String in keys:
		var nodes: Array = by_key [key]
		await _r("script %s silenced (%d)" % [key, nodes.size()], func() -> void:
			p._silence_nodes(nodes))


func _fill(kind: int, n: int) -> int:
	var paths: Array [BeltPath] = []
	var total:= 0.0
	for path in _paths():
		path.run.clear()
		if path.run.catching and path.run.length() > 1.0:
			paths.append(path)
			total += path.run.length()
	if paths.is_empty() or total <= 0.0:
		return 0
	var strands:= Cfg.WAD_BASE_STRANDS
	var made:= 0
	for path in paths:
		var shape:= path.shape_of_kind(kind, strands)
		if shape.is_empty():
			continue
		var reach:= float(shape ["reach"])
		var lift:= float(shape ["rest"])
		var length:= path.run.length()
		var k:= int(round(float(n) * length / total))
		var pitch:= (length - 0.6) / maxf(float(k), 1.0)
		var room:= maxf(reach * 2.0, path.run.spacing)
		if pitch < room:
			k = int(floor((length - 0.6) / room))
			pitch = (length - 0.6) / maxf(float(k), 1.0)
		for j in range(k - 1, -1, -1):
			var s:= 0.3 + float(j) * pitch
			var state: Variant = { "strands": strands } if kind == BeltRun.Kind.WAD else null
			if path.run.board(kind, strands, -1, reach, 0.0, lift, s, path.run.speed, state):
				made += 1
		path.wake()
	return made


func _fill_to(kind: int, n: int) -> int:
	var made:= _fill(kind, n)
	if made > 0 and made < n:
		made = _fill(kind, int(ceil(float(n) * float(n) / float(made))))
	return made


func _fill_rows(n: int) -> void:


	var decay_was:= Cfg.belt_decay
	Cfg.belt_decay = false
	print("HUNT: belt decay off for the fill (cap %d would shed the rest)" % Cfg.belt_cap)
	for entry: Array in FILL_KINDS:
		var kind: int = entry [0]
		var name: String = entry [1]
		_now_section = "%d %s on belts" % [n, name]
		_undo_all()
		var made:= _fill_to(kind, n)
		print("HUNT: filled the belts with %d %s (asked %d)" % [made, name, n])
		_since_base = 0
		var label:= "%d %s aboard" % [made, name]
		_section [label] = _now_section
		await p._row(label, func() -> void:
			_undo_all()
			_fill_to(kind, n))
		_say_cargo()
		for pair: Array in [["hidden", func() -> void: _hide(_cargo_bins(-1))],
				["shadows off", func() -> void: p._uncast(_cargo_bins(-1))],
				["drawer stopped", func() -> void:
					if BeltRunBatch.instance != null:
						_put(BeltRunBatch.instance, "process_mode", Node.PROCESS_MODE_DISABLED)],
				["belt paths silenced", func() -> void: _silence(_paths())]]:
			var what: Callable = pair [1]
			await _r("%s: %s" % [name, pair [0]], func() -> void:
				_fill_to(kind, n)
				what.call())
	_undo_all()
	for path in _paths():
		path.run.clear()
	Cfg.belt_decay = decay_was
	print("HUNT: belts emptied after the fill")


func _physics_rows() -> void:
	_now_section = "physics"
	var areas:= _all_of("Area3D").filter(func(a: Area3D) -> bool: return a.monitoring or a.monitorable)
	await _r("every Area3D off (%d)" % areas.size(), func() -> void:
		for a: Area3D in areas:
			_put(a, "monitoring", false)
			_put(a, "monitorable", false))
	var shapes: Array = []
	for b: Node3D in world.builds.all_buildings():
		if not is_instance_valid(b):
			continue
		var stack: Array [Node] = [b]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for kid: Node in node.get_children():
				stack.append(kid)
			if node is CollisionShape3D and not (node as CollisionShape3D).disabled:
				shapes.append(node)
	await _r("every building collision shape off (%d)" % shapes.size(), func() -> void:
		for s: CollisionShape3D in shapes:
			_put(s, "disabled", true))


func _report() -> void:
	var rows: Array = p._rows
	print("\n=== FPS HUNT ===")
	print("Each row against the average of the nearest baseline before and after it.")
	print("| section | switched off | frame ms | fps | saves ms | proc ms | phys ms | rCPU ms | GPU ms | draws |")
	print("| :-- | :-- | --: | --: | --: | --: | --: | --: | --: | --: |")
	var out: Array = []
	for i in rows.size():
		var r: Dictionary = rows [i]
		var label: String = r ["label"]
		var is_base:= label.begins_with("everything on") or label.ends_with(" aboard")
		var before:= _base_near(rows, i, -1)
		var after:= _base_near(rows, i, 1)
		var floor_ms: float = float(r ["wall"])
		if not is_base:
			var picks: Array [float] = []
			if before >= 0:
				picks.append(float(rows [before] ["wall"]))
			if after >= 0 and _same_block(rows, before, after):
				picks.append(float(rows [after] ["wall"]))
			if not picks.is_empty():
				floor_ms = 0.0
				for v in picks:
					floor_ms += v
				floor_ms /= picks.size()
		var saves: float = floor_ms - float(r ["wall"])
		print("| %s | %s | %.2f | %.0f | %s | %.2f | %.2f | %.2f | %.2f | %.0f |" % [
			_section.get(label, "baseline"), label, r ["wall"], 1000.0 / maxf(r ["wall"], 0.001),
			"-" if is_base else "%+.2f" % saves, r ["proc"], r ["phys"], r ["cpu"], r ["gpu"], r ["draws"]])
		out.append({ "section": _section.get(label, "baseline"), "label": label,
			"wall": r ["wall"], "saves": 0.0 if is_base else saves, "proc": r ["proc"],
			"phys": r ["phys"], "cpu": r ["cpu"], "gpu": r ["gpu"], "draws": r ["draws"],
			"median": r ["median_ms"], "p95": r ["p95_ms"], "base": is_base })
	print("HUNT_JSON " + JSON.stringify(out))


func _base_near(rows: Array, i: int, step: int) -> int:
	var j:= i + step
	while j >= 0 and j < rows.size():
		var label: String = rows [j] ["label"]
		if label.begins_with("everything on") or label.ends_with(" aboard"):
			return j
		j += step
	return -1


func _same_block(rows: Array, a: int, b: int) -> bool:
	if a < 0 or b < 0:
		return false
	return str(rows [a] ["label"]).ends_with(" aboard") == str(rows [b] ["label"]).ends_with(" aboard") and not str(rows [b] ["label"]).ends_with(" aboard")
