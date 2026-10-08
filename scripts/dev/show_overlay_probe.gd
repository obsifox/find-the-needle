class_name DevShowOverlayProbe
extends Node


const ZONE_NAME:= "ProbeZoneVolume"
const ZONE_AT:= Vector3(20.0, 2.0, 20.0)
const ZONE_MOVED:= Vector3(24.0, 3.0, 22.0)

const STRAND_NAME:= "ProbeStrandBody"
const STRAND_AT:= Vector3(20.0, 2.0, 24.0)

var world: Node3D

var _fails: PackedStringArray = PackedStringArray()
var _view: DebugView


var _menu: DebugMenu
var _area: Area3D
var _strand: StaticBody3D


func _log(msg: String) -> void:
	print("[showoverlay] %s" % msg)


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	await _settle(6)

	_stand_the_props()
	_menu = world.debug_menu
	if _menu == null:
		_fails.append("no debug menu in this build, so nothing can reach the overlay")
		_view = DebugView.new()
		_view.name = "DebugView"
		world.add_child(_view)
	else:
		_view = _menu._ensure_view()
	await _settle(2)

	await _check_zone_drawn()
	await _check_zone_follows()
	await _check_body_filter()
	_check_no_intrusion()
	await _check_menu()
	await _check_off()

	if _fails.is_empty():
		_log("OK")
	else:
		for f in _fails:
			_log("FAIL: %s" % f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _stand_the_props() -> void:
	_area = Area3D.new()
	_area.name = ZONE_NAME
	_area.collision_layer = 0
	_area.collision_mask = Cfg.L_STRAND
	var box:= BoxShape3D.new()
	box.size = Vector3(2.0, 1.0, 3.0)
	var cs:= CollisionShape3D.new()
	cs.shape = box
	_area.add_child(cs)
	world.add_child(_area)
	_area.global_position = ZONE_AT

	_strand = StaticBody3D.new()
	_strand.name = STRAND_NAME
	_strand.collision_layer = Cfg.L_STRAND
	_strand.collision_mask = 0
	var ball:= SphereShape3D.new()
	ball.radius = 0.2
	var scs:= CollisionShape3D.new()
	scs.shape = ball
	_strand.add_child(scs)
	world.add_child(_strand)
	_strand.global_position = STRAND_AT


func _check_zone_drawn() -> void:
	if _view.set_zones(true) <= 0:
		_fails.append("zones on drew nothing at all")
	await _settle(2)
	if _drawn_zone() == null:
		_fails.append("the zone %s was not drawn" % ZONE_NAME)


func _check_zone_follows() -> void:
	var holder:= _drawn_zone()
	if holder == null:
		return
	if not holder.global_position.is_equal_approx(ZONE_AT):
		_fails.append("drawn zone stands at %s, the real one at %s"
			% [holder.global_position, ZONE_AT])
	_area.global_position = ZONE_MOVED
	await _settle(2)


	if not is_instance_valid(holder):
		_fails.append("the drawn zone was freed when the real one moved")
		return
	if not holder.global_position.is_equal_approx(ZONE_MOVED):
		_fails.append("drawn zone did not follow: %s, wanted %s"
			% [holder.global_position, ZONE_MOVED])


func _check_body_filter() -> void:
	_view.set_bodies(DebugView.Bodies.SOLID)
	await _settle(2)
	if _drawn_body() != null:
		_fails.append("SOLID drew a strand, which is the whole point of SOLID")
	_view.set_bodies(DebugView.Bodies.ALL)
	await _settle(2)
	if _drawn_body() == null:
		_fails.append("ALL left the strand out")


func _check_no_intrusion() -> void:
	for node: Node in [_area, _strand]:
		for kid in node.get_children():
			if kid is MeshInstance3D or kid is Label3D:
				_fails.append("%s picked up a debug child (%s)"
					% [node.name, kid.name])


func _check_menu() -> void:
	if _menu == null:
		return
	_view.set_zones(false)
	_view.set_bodies(DebugView.Bodies.OFF)
	_menu._zones_button.pressed.emit()
	await _settle(2)
	if not _view.zones:
		_fails.append("the Zones button did not switch zones on")
	if _menu._zones_button.text != "Zones: ON":
		_fails.append("the Zones button reads '%s' with zones on"
			% _menu._zones_button.text)


	var seen: Array [int] = []
	for i in 3:
		_menu._bodies_button.pressed.emit()
		seen.append(_view.bodies)
	if seen != [DebugView.Bodies.SOLID, DebugView.Bodies.ALL,
			DebugView.Bodies.OFF]:
		_fails.append("the Collisions button walked %s" % [seen])

	var before: int = _menu._render_mode
	_menu._render_button.pressed.emit()
	if _menu._render_mode == before:
		_fails.append("the Render button did not move")
	if get_viewport().debug_draw != DebugMenu.RENDER_MODES [_menu._render_mode] [1]:
		_fails.append("the render mode on screen is not the one the button says")

	while _menu._render_mode != 0:
		_menu._render_button.pressed.emit()


func _check_off() -> void:
	_view.set_zones(false)
	_view.set_bodies(DebugView.Bodies.OFF)
	await _settle(2)
	if not _view.is_idle():
		_fails.append("both switches off and it still says it is working")
	if _drawn_zone() != null or _drawn_body() != null:
		_fails.append("meshes are still standing after both switches went off")
	if _view.is_processing():
		_fails.append("still running its per-frame pass with nothing to draw")


func _drawn_zone() -> Node3D:
	return _find_for(_view.get_node_or_null("Zones"), _area)


func _drawn_body() -> Node3D:
	return _find_for(_view.get_node_or_null("Bodies"), _strand)


func _find_for(root: Node, src_owner: Node) -> Node3D:
	if root == null:
		return null
	for entry in _view._tracked:
		var src: Node = entry ["src"]
		if not is_instance_valid(src) or src.get_parent() != src_owner:
			continue
		var vis: Node3D = entry ["vis"]
		if is_instance_valid(vis) and vis.get_parent() == root:
			return vis
	return null


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
