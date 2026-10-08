class_name ShadowLod
extends Node


const SIZE_GAIN:= 6.0


const HOLD:= 1.1


const SWEEP_FRAMES:= 12


const MIN_PER_FRAME:= 32


var _casters: Array [GeometryInstance3D] = []


var _known: Dictionary = { }


var _mm_boxes: Dictionary = { }
var _cursor:= 0


var _dirty:= true


static var walk_when_off:= "--shadowlodwalk" in OS.get_cmdline_user_args()


var _all_off:= false

var _off_run:= 0


var _off_kept:= 0

var _builds: BuildManager
var _props: PropManager


func setup(builds: BuildManager, props: PropManager) -> void:
	_builds = builds
	_props = props
	if _builds != null and not _builds.changed.is_connected(mark_dirty):
		_builds.changed.connect(mark_dirty)


	if _props != null and not _props.item_added.is_connected(_adopt):
		_props.item_added.connect(_adopt)


func mark_dirty() -> void:
	_dirty = true
	_mm_boxes.clear()


func _adopt(item: Node) -> void:
	if item == null:
		return
	var stack: Array [Node] = [item]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var g:= node as GeometryInstance3D


		if g != null and g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			var id:= g.get_instance_id()
			if not _known.has(id):
				_known [id] = true
				_casters.append(g)


				if _gate_off():
					g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for kid: Node in node.get_children():
			stack.append(kid)


func tick(eye: Vector3) -> void:
	if _dirty:
		_rebuild()
	if _casters.is_empty():
		return
	var base: float = Cfg.yard_shadow_distance


	var off:= _gate_off()
	if not off:
		_all_off = false
		_off_run = 0
	elif _all_off:


		if _casters.size() > _off_kept * 2 + MIN_PER_FRAME:
			_prune()
			_off_kept = _casters.size()
		return
	var per_frame:= maxi(MIN_PER_FRAME, _casters.size() / SWEEP_FRAMES)
	var checked:= 0


	var dead: Array [int] = []
	while checked < per_frame and checked < _casters.size():
		checked += 1
		_cursor += 1
		if _cursor >= _casters.size():
			_cursor = 0
		var g:= _casters [_cursor]
		if not is_instance_valid(g) or not g.is_inside_tree():
			dead.append(_cursor)
			continue
		if off:

			if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		var aabb:= _box(g)
		var radius:= aabb.size.length() * 0.5


		var centre: Vector3 = g.global_transform * aabb.get_center()
		var gate:= base + radius * SIZE_GAIN
		var d:= eye.distance_to(centre)


		var casting:= g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var want:= d <= (gate * HOLD if casting else gate)
		if base <= 0.0:

			want = false
		var mode:= GeometryInstance3D.SHADOW_CASTING_SETTING_ON if want else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if g.cast_shadow != mode:
			g.cast_shadow = mode


	dead.sort()


	var below:= 0
	for i in range(dead.size() - 1, -1, -1):
		var g:= _casters [dead [i]]
		_known.erase(g.get_instance_id() if is_instance_valid(g) else 0)
		_casters.remove_at(dead [i])
		if dead [i] <= _cursor:
			below += 1
	if not dead.is_empty():
		_cursor = clampi(_cursor - below, -1, maxi(_casters.size() - 1, 0))
	if off:
		_off_run += checked
		if _off_run >= _casters.size():
			_all_off = true
			_off_kept = _casters.size()


func _gate_off() -> bool:
	return Cfg.yard_shadow_distance <= 0.0 and not walk_when_off


func _rebuild() -> void:
	_dirty = false
	_prune()
	var roots: Array [Node] = []
	if _props != null:
		for item in _props.items:
			if item is Node3D and is_instance_valid(item):
				roots.append(item)
	if _builds != null:
		roots.append_array(_builds.every_placed())
	for root: Node in roots:
		_adopt(root)


func _box(g: GeometryInstance3D) -> AABB:
	if not g is MultiMeshInstance3D:
		return g.get_aabb()
	var id:= g.get_instance_id()
	var box: Variant = _mm_boxes.get(id)
	if box == null:
		box = g.get_aabb()
		_mm_boxes [id] = box
	return box


func _prune() -> void:
	var live: Array [GeometryInstance3D] = []
	for g in _casters:
		if is_instance_valid(g) and g.is_inside_tree():
			live.append(g)
		else:
			_known.erase(g.get_instance_id() if is_instance_valid(g) else 0)
	_casters = live
	_cursor = 0

	_off_run = 0


func caster_count() -> int:
	return _casters.size()
