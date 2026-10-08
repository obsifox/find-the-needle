class_name MachineDrawDistance
extends Node


const EXCLUDED:= ["conveyor", "conveyor_corner", "platform", "stair", "railing",
	"yard_wall", "roof", "power_pole", "power_box", "water_main"]
const MARGIN:= 4.0

var _builds: BuildManager
var _roots: Dictionary = { }
var _entries: Dictionary = { }
var _queued:= false


var _swept: Dictionary = { }


var _last_metres:= -1.0


var _last_quality:= -1


func setup(builds: BuildManager) -> void:
	_builds = builds
	_builds.changed.connect(refresh)
	Cfg.gfx_changed.connect(refresh)
	get_tree().node_added.connect(_node_added)
	refresh()


func refresh() -> void:
	if _queued:
		return
	_queued = true
	call_deferred("_refresh")


func _refresh() -> void:
	_queued = false
	get_parent()._apply_machine_distance_fog()
	_roots.clear()
	for root: Node3D in _builds.every_placed():
		var script:= root.get_script() as Script
		if script == null or script.resource_path.get_file().get_basename() in EXCLUDED:
			continue
		_roots [root.get_instance_id()] = true
	for id: int in _entries.keys():
		var geometry = _entries [id] ["geometry"]
		if not is_instance_valid(geometry):
			_entries.erase(id)
		elif not _belongs(geometry):
			_restore(_entries [id])
			_entries.erase(id)


	for id: int in _swept.keys():
		if not _roots.has(id):
			_swept.erase(id)
	var metres:= Cfg.machine_distance_metres()
	var was:= _last_metres
	_last_metres = metres
	var quality_moved:= _last_quality >= 0 and _last_quality != int(Cfg.quality)
	_last_quality = int(Cfg.quality)
	if metres == 0.0:
		for entry: Dictionary in _entries.values():
			_restore(entry)
		return


	var sweep_all:= was <= 0.0


	for root: Node3D in _builds.every_placed():
		var id:= root.get_instance_id()
		if not _roots.has(id) or (not sweep_all and _swept.has(id)):
			continue
		_swept [id] = true
		for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
			_adopt(node as GeometryInstance3D)


	if not sweep_all and (quality_moved or not is_equal_approx(metres, was)):
		for entry: Dictionary in _entries.values():
			var geometry = entry ["geometry"]
			if is_instance_valid(geometry):
				_adopt(geometry as GeometryInstance3D)


func _node_added(node: Node) -> void:
	if node is GeometryInstance3D:

		call_deferred("_adopt_added", node)


func _adopt_added(node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var owner_id:= _root_of(node)
	if owner_id != 0:
		if Cfg.machine_distance_metres() > 0.0:
			_adopt(node as GeometryInstance3D)
		else:


			_swept.erase(owner_id)
	elif _entries.has(node.get_instance_id()):
		var id: int = node.get_instance_id()
		_restore(_entries [id])
		_entries.erase(id)


func _belongs(node: Node) -> bool:
	return _root_of(node) != 0


func _root_of(node: Node) -> int:
	var ancestor:= node.get_parent()
	while ancestor != null:
		var id:= ancestor.get_instance_id()
		if _roots.has(id):
			return id
		ancestor = ancestor.get_parent()
	return 0


func _adopt(geometry: GeometryInstance3D) -> void:
	var id:= geometry.get_instance_id()
	if not _entries.has(id):
		_entries [id] = { "geometry": geometry, "end": geometry.visibility_range_end,
			"margin": geometry.visibility_range_end_margin }
	var original: Dictionary = _entries [id]


	if geometry.has_meta(MachineLod.LOD_END_META):
		original ["end"] = float(geometry.get_meta(MachineLod.LOD_END_META))

	var box:= geometry.custom_aabb
	if not box.has_volume():
		box = geometry.get_aabb()
	var scale:= geometry.global_basis.get_scale().abs()
	var radius:= (box.size * scale).length() * 0.5
	var limit:= Cfg.machine_distance_metres() + radius


	var sign_metres:= float(Cfg.preset().get("sign_distance", 0.0))
	if sign_metres > 0.0 and geometry is Label3D and not (geometry as Label3D).fixed_size:
		limit = minf(limit, sign_metres + radius)
	if float(original ["end"]) > 0.0 and float(original ["end"]) <= limit:
		_restore(original)
	else:
		geometry.visibility_range_end = limit
		geometry.visibility_range_end_margin = MARGIN


func _restore(entry: Dictionary) -> void:
	var geometry = entry ["geometry"]
	if is_instance_valid(geometry):


		if geometry.has_meta(MachineLod.LOD_END_META):
			entry ["end"] = float(geometry.get_meta(MachineLod.LOD_END_META))
		geometry.visibility_range_end = entry ["end"]
		geometry.visibility_range_end_margin = entry ["margin"]


func _exit_tree() -> void:
	for entry: Dictionary in _entries.values():
		_restore(entry)
