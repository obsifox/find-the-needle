class_name MachineLod
extends Node


const SWAP_BASE:= 30.0


const SIZE_GAIN:= 6.0


const HOLD:= 1.08


const LOD_END_META:= &"machine_lod_end"


const SWEEP_FRAMES:= 8


const MIN_PER_FRAME:= 8


static var _merged: Dictionary = { }


static var _watched: Array [Dictionary] = []
static var _cursor:= 0


static func adopt(root: Node3D, model: Node3D, key: String) -> void:
	if root == null or model == null or not model.is_inside_tree():
		return
	for w in _watched:
		if w ["root"] == root:
			return


	var near: Array [GeometryInstance3D] = []
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D


		if mi == null or not mi.is_visible_in_tree():
			continue
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		near.append(mi)
	if near.is_empty():
		return
	var mesh: ArrayMesh = _merged.get(key, null)
	if mesh == null:
		mesh = _merge(model, near)
		if mesh == null:
			return
		_merged [key] = mesh
	var far:= MeshInstance3D.new()
	far.name = "FarLod"
	far.mesh = mesh


	model.add_child(far)
	far.transform = Transform3D.IDENTITY
	var gate:= _gate(mesh)


	for mi in near:
		mi.visibility_range_begin = 0.0
		mi.visibility_range_end = gate
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mi.set_meta(LOD_END_META, gate)
	far.visibility_range_begin = gate
	far.visibility_range_end = 0.0
	far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


	var mixers: Array = []
	for n: Node in root.find_children("*", "AnimationMixer", true, false):
		mixers.append(n)
	_watched.append({ "root": root, "near": near, "far": far, "mixers": mixers,
		"gate": gate, "base": swap_base(), "swapped": false })


static func tick(eye: Vector3) -> void:
	if not _hooked:
		_hook()
	if not _pending.is_empty():
		_adopt_pending()
	if _watched.is_empty():
		return
	var per_frame:= maxi(MIN_PER_FRAME, _watched.size() / SWEEP_FRAMES)
	var checked:= 0
	var stale:= false
	while checked < per_frame and checked < _watched.size():
		checked += 1
		_cursor += 1
		if _cursor >= _watched.size():
			_cursor = 0
		var w: Dictionary = _watched [_cursor]


		var root = w ["root"]
		if not is_instance_valid(root) or not root.is_inside_tree():
			stale = true
			continue
		if w.has("paused") and not clips_enabled:
			continue
		var gate: float = w ["gate"]
		var was: bool = w ["swapped"]
		var d:= eye.distance_to(root.global_position)

		var now:= d > (gate * HOLD if was else gate)
		if now == was:
			continue
		w ["swapped"] = now
		if w.has("paused"):
			_still_clips(w, now)
			continue


		for m in (w ["mixers"] as Array):
			if is_instance_valid(m):
				(m as AnimationMixer).active = not now
	if stale:
		var kept: Array [Dictionary] = []
		for w: Dictionary in _watched:
			var root = w ["root"]
			if is_instance_valid(root) and root.is_inside_tree():
				kept.append(w)
		_watched = kept
		_cursor = 0


static func census() -> Array [int]:
	var swapped:= 0
	for w: Dictionary in _watched:
		if bool(w ["swapped"]):
			swapped += 1
	return [_watched.size(), swapped]


const CLIP_MACHINES: PackedStringArray = [
	"hay_pulper", "hay_generator", "borehole_pump", "paper_machine",
	"hay_pelletizer", "briquette_press", "hay_compressor", "hay_wrapper",
	"needle_radar",
]


static var clips_enabled:= not ("--noclipsleep" in OS.get_cmdline_user_args())


static var _pending: Array = []
static var _hooked:= false


static func _hook() -> void:
	_hooked = true


	Cfg.quality_changed.connect(func(_level) -> void: regate())
	var tree:= Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_pending.append_array(tree.root.find_children("*", "AnimationMixer", true, false))
	tree.node_added.connect(func(node: Node) -> void:
		if node is AnimationMixer:
			_pending.append(node))


static func _adopt_pending() -> void:
	var batch:= _pending
	_pending = []
	for m in batch:


		if not is_instance_valid(m):
			continue
		var mixer:= m as AnimationMixer
		if mixer == null or not mixer.is_inside_tree():
			continue
		var root:= _clip_owner(mixer)


		if root == null or bool(root.get("placement_preview")):
			continue
		_watch_clips(root, mixer)


static func _clip_owner(mixer: Node) -> Node3D:
	var at:= mixer.get_parent()
	while at != null:
		var script:= at.get_script() as Script
		if script != null and script.resource_path.get_file().get_basename() in CLIP_MACHINES:
			return at as Node3D
		at = at.get_parent()
	return null


static func _watch_clips(root: Node3D, mixer: AnimationMixer) -> void:
	for w: Dictionary in _watched:
		if w ["root"] != root:
			continue

		if not w.has("paused"):
			return
		if not (w ["mixers"] as Array).has(mixer):
			(w ["mixers"] as Array).append(mixer)
			if bool(w ["swapped"]) and mixer.active:
				mixer.active = false
				(w ["paused"] as Array).append(mixer)
		return
	_watched.append({ "root": root, "near": [], "far": null, "mixers": [mixer],
		"gate": _clip_gate(root), "base": swap_base(), "swapped": false, "paused": [] })


static func set_clip_sleep(on: bool) -> void:
	clips_enabled = on
	if on:
		return
	for w: Dictionary in _watched:
		if w.has("paused"):
			_still_clips(w, false)
			w ["swapped"] = false


static func _still_clips(w: Dictionary, far: bool) -> void:
	var paused: Array = w ["paused"]
	if far:
		for m in (w ["mixers"] as Array):
			if is_instance_valid(m) and (m as AnimationMixer).active:
				(m as AnimationMixer).active = false
				paused.append(m)
		if "--clipsleepall" in OS.get_cmdline_user_args():
			print("[machinelod] stilled %d clips on %s" % [paused.size(), w ["root"].name])
		return
	for m in paused:
		if is_instance_valid(m):
			(m as AnimationMixer).active = true
	paused.clear()


static func _clip_gate(root: Node3D) -> float:


	if "--clipsleepall" in OS.get_cmdline_user_args():
		return 0.0
	var into:= root.global_transform.affine_inverse()
	var box:= AABB()
	var first:= true
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b:= (into * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return swap_base() + box.size.length() * 0.5 * SIZE_GAIN


static func _gate(mesh: ArrayMesh) -> float:
	return swap_base() + mesh.get_aabb().size.length() * 0.5 * SIZE_GAIN


static func swap_base() -> float:
	return float(Cfg.preset().get("machine_lod", SWAP_BASE))


static func regate() -> void:
	var base:= swap_base()
	for w: Dictionary in _watched:
		var gate: float = w ["gate"]

		if gate <= 0.0 or float(w ["base"]) == base:
			continue
		gate += base - float(w ["base"])
		w ["gate"] = gate
		w ["base"] = base
		for mi in (w ["near"] as Array):
			if is_instance_valid(mi):
				(mi as GeometryInstance3D).visibility_range_end = gate
				(mi as GeometryInstance3D).set_meta(LOD_END_META, gate)
		var far = w ["far"]
		if is_instance_valid(far):
			(far as GeometryInstance3D).visibility_range_begin = gate


static func _merge(model: Node3D, near: Array [GeometryInstance3D]) -> ArrayMesh:
	var into:= model.global_transform.affine_inverse()
	var tools: Dictionary = { }
	var mats: Dictionary = { }
	for mi: GeometryInstance3D in near:
		var src:= mi as MeshInstance3D
		if src == null or src.mesh == null:
			continue


		if src.skin != null:
			continue
		var at:= into * src.global_transform
		for s in src.mesh.get_surface_count():
			var mat:= src.get_active_material(s)
			var id:= mat.get_instance_id() if mat != null else 0
			if not tools.has(id):
				var st:= SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools [id] = st
				mats [id] = mat
			(tools [id] as SurfaceTool).append_from(src.mesh, s, at)
	if tools.is_empty():
		return null
	var out:= ArrayMesh.new()
	for id: int in tools:
		var st: SurfaceTool = tools [id]
		st.index()
		var mesh:= st.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
			mesh.surface_get_arrays(0))
		out.surface_set_material(out.get_surface_count() - 1, mats [id])
	return out if out.get_surface_count() > 0 else null
