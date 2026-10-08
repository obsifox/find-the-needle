class_name BeltItemBatch
extends Node3D


const TILE:= 16.0
const INITIAL_CAPACITY:= 32
static var instance: BeltItemBatch
static var enabled:= not ("--no-belt-item-batch" in OS.get_cmdline_user_args())
static var suppress_mesh_updates:= not ("--legacy-cargo-mesh-updates" in OS.get_cmdline_user_args())
static var fixed_bounds_enabled:= not ("--legacy-cargo-bounds" in OS.get_cmdline_user_args())


static var hide_empty:= not ("--keepemptymm" in OS.get_cmdline_user_args())


const VISIBLE_EVERY:= 15

class Record:
	var body: Carryable
	var source: MeshInstance3D
	var layers: int
	var source_mesh: Mesh
	var draw_mesh: Mesh
	var group: CargoGroup
	var slot:= -1
	var tile: Vector3i
	var shadow:= -1
	var gi:= -1
	var pose: Transform3D
	var notify_transform:= true
	var suppressed:= false
	var culled:= false
	var local_bounds: AABB


	var visible:= true
	var visible_in:= 0

class CargoGroup:
	var node: MultiMeshInstance3D
	var records: Array [Record] = []
	var bounds: AABB


	var shown:= true

var _records: Array [Record] = []
var _by_body: Dictionary = { }
var _meshes: Dictionary = { }
var _buckets: Dictionary = { }


static func adopt(body: RigidBody3D) -> void:
	if not enabled or DisplayServer.get_name() == "headless" or not body is Carryable or not body.is_inside_tree():
		return


	if not (body is HayWad or body is HayBale or body is EcoBrick
			or body is FoiledBale or body is PaperRoll or body is FeedDisc
			or body is HayPulp):
		return
	if instance == null:
		var scene:= body.get_tree().current_scene
		if scene == null:
			return
		var made:= BeltItemBatch.new()
		made.name = "BeltItemBatch"
		scene.add_child(made)
	instance._adopt(body as Carryable)


static func release(body: RigidBody3D) -> void:
	if instance != null and is_instance_valid(body):
		instance._release(body.get_instance_id())


func _enter_tree() -> void:
	instance = self
	top_level = true

	process_priority = 100


func _exit_tree() -> void:
	for r in _records:
		_unseat(r)
		_restore_source(r)
		if is_instance_valid(r.source):
			var callback:= _source_visibility_changed.bind(r)
			if r.source.visibility_changed.is_connected(callback):
				r.source.visibility_changed.disconnect(callback)
	_records.clear()
	_by_body.clear()
	_buckets.clear()
	_meshes.clear()
	if instance == self:
		instance = null


func _adopt(body: Carryable) -> void:
	var id:= body.get_instance_id()
	if _by_body.has(id):
		return
	var mine: Array [Record] = []
	for source in body._meshes:
		if source.mesh == null or not source.mesh is ArrayMesh or source.layers == 0:
			continue
		var r:= Record.new()
		r.body = body
		r.source = source
		r.layers = source.layers


		r.visible_in = _records.size() % VISIBLE_EVERY
		r.visible = source.is_visible_in_tree()
		source.visibility_changed.connect(_source_visibility_changed.bind(r))
		_records.append(r)
		mine.append(r)
	if mine.is_empty():
		return
	_by_body [id] = mine
	body.tree_exiting.connect(_release.bind(id), CONNECT_ONE_SHOT)


func _release(id: int) -> void:
	if not _by_body.has(id):
		return
	var mine: Array = _by_body [id]
	for r: Record in mine:
		_unseat(r)
		_restore_source(r)
		if is_instance_valid(r.source):
			var visibility_callback:= _source_visibility_changed.bind(r)
			if r.source.visibility_changed.is_connected(visibility_callback):
				r.source.visibility_changed.disconnect(visibility_callback)
		_records.erase(r)
	if not mine.is_empty() and is_instance_valid(mine [0].body):
		var body: Carryable = mine [0].body
		var callback:= _release.bind(id)
		if body.tree_exiting.is_connected(callback):
			body.tree_exiting.disconnect(callback)
	_by_body.erase(id)


func _restore_source(r: Record) -> void:
	if not is_instance_valid(r.source):
		return
	r.culled = false
	if r.suppressed:
		r.source.set_notify_transform(r.notify_transform)
		r.suppressed = false


		if r.source.is_inside_tree():
			RenderingServer.instance_set_transform(r.source.get_instance(), r.source.global_transform)
	BeltBatch.set_layers(r.source, r.layers)


func _source_visibility_changed(r: Record) -> void:
	r.culled = false
	r.visible_in = 0


func _mesh_for(source: MeshInstance3D) -> Mesh:
	var key: Array = [source.mesh.get_rid()]
	for i in source.mesh.get_surface_count():
		var mat:= source.get_active_material(i)
		key.append(mat.get_rid() if mat != null else RID())
	if _meshes.has(key):
		return _meshes [key]
	var mesh:= source.mesh.duplicate() as ArrayMesh
	for i in mesh.get_surface_count():
		mesh.surface_set_material(i, source.get_active_material(i))
	_meshes [key] = mesh
	return mesh


func _bucket(key: Array, r: Record) -> CargoGroup:
	if _buckets.has(key):
		return _buckets [key]
	var b:= CargoGroup.new()
	b.node = MultiMeshInstance3D.new()
	b.node.multimesh = MultiMesh.new()
	b.node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	b.node.multimesh.mesh = r.draw_mesh
	b.node.multimesh.instance_count = INITIAL_CAPACITY
	b.node.multimesh.visible_instance_count = 0
	if fixed_bounds_enabled:
		b.bounds = (r.pose * r.local_bounds).grow(0.5)
		b.node.multimesh.custom_aabb = b.bounds
	b.node.cast_shadow = r.source.cast_shadow
	b.node.layers = r.layers
	b.node.gi_mode = r.source.gi_mode

	b.shown = not hide_empty
	b.node.visible = b.shown
	add_child(b.node)
	_buckets [key] = b
	return b


func _process(_delta: float) -> void:
	for r in _records:
		var source:= r.source
		if not is_instance_valid(source) or not source.is_inside_tree():
			_unseat(r)
			_restore_source(r)


			r.visible_in = 0
			continue


		r.visible_in -= 1
		if r.visible_in < 0:
			r.visible_in = VISIBLE_EVERY - 1
			r.visible = source.is_visible_in_tree()
		if not r.visible or source.material_overlay != null or source.transparency > 0.0:
			_unseat(r)
			_restore_source(r)
			continue
		if source.mesh == null:
			_unseat(r)
			continue
		var mesh_changed:= source.mesh != r.source_mesh
		if mesh_changed:
			r.source_mesh = source.mesh
			r.draw_mesh = _mesh_for(source)
			r.local_bounds = r.draw_mesh.get_aabb().grow(0.25)
		var pose:= source.global_transform
		var p:= pose.origin / TILE
		var tile:= Vector3i(floori(p.x), floori(p.y), floori(p.z))
		if r.group == null or mesh_changed or r.tile != tile or r.shadow != source.cast_shadow or r.gi != source.gi_mode:
			_unseat(r)
			r.tile = tile
			r.shadow = source.cast_shadow
			r.gi = source.gi_mode
			r.pose = pose
			var key: Array = [tile, r.draw_mesh.get_rid(), r.shadow, r.layers, r.gi]
			_seat(r, _bucket(key, r))
		elif r.pose != pose:
			r.pose = pose
			if fixed_bounds_enabled:
				_ensure_bounds(r)
			r.group.node.multimesh.set_instance_transform(r.slot, pose)
		if suppress_mesh_updates and not r.suppressed:
			r.notify_transform = source.is_transform_notification_enabled()
			source.set_notify_transform(false)
			r.suppressed = true
		var relayered:= source.layers != 0
		if relayered:
			BeltBatch.set_layers(source, 0)

		if relayered or not r.culled:
			RenderingServer.instance_set_visible(source.get_instance(), false)
			r.culled = true


func _seat(r: Record, group: CargoGroup) -> void:
	r.group = group
	if fixed_bounds_enabled:
		_ensure_bounds(r)
	r.slot = group.records.size()
	group.records.append(r)
	var mm:= group.node.multimesh
	if group.records.size() > mm.instance_count:
		mm.instance_count *= 2

		for previous in group.records:
			mm.set_instance_transform(previous.slot, previous.pose)
	else:
		mm.set_instance_transform(r.slot, r.pose)
	mm.visible_instance_count = group.records.size()
	_show(group)


func _ensure_bounds(r: Record) -> void:
	var bounds:= r.pose * r.local_bounds
	if not r.group.bounds.encloses(bounds):
		r.group.bounds = r.group.bounds.merge(bounds)
		r.group.node.multimesh.custom_aabb = r.group.bounds


func _unseat(r: Record) -> void:
	var group:= r.group
	if group == null:
		return
	var last: Record = group.records.pop_back()
	if last != r:
		last.slot = r.slot
		group.records [r.slot] = last
		group.node.multimesh.set_instance_transform(last.slot, last.pose)
	group.node.multimesh.visible_instance_count = group.records.size()
	_show(group)
	r.group = null
	r.slot = -1


func _show(group: CargoGroup) -> void:
	var want:= not hide_empty or not group.records.is_empty()
	if group.shown != want:
		group.shown = want
		group.node.visible = want
