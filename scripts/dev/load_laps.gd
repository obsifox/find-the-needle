class_name DevLoadLaps
extends RefCounted


const SHOW_MS:= 25.0


const DEPTH:= 3

var _world: Node
var _mark:= 0
var _frame:= 0
var _last:= "(frame start)"


func watch(world: Node) -> void:
	_world = world
	_mark = Time.get_ticks_usec()
	world.get_tree().node_added.connect(_on_node_added)


	world.get_tree().physics_frame.connect(_lap.bind("until physics began"))
	world.get_tree().process_frame.connect(_lap.bind("until process began"))
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)


func _on_node_added(n: Node) -> void:
	var depth:= 0
	var p:= n.get_parent()
	while p != null and p != _world and depth < DEPTH:
		p = p.get_parent()
		depth += 1
	if p != _world:
		return
	var here:= "%s/%s" % [n.get_parent().name, n.name]
	_lap("after %s, until %s" % [_last, here])
	_last = here


func _on_pre_draw() -> void:
	_lap("after %s, until the frame ended" % _last)


func _on_post_draw() -> void:
	_mark = Time.get_ticks_usec()
	_frame += 1
	_last = "(frame start)"


func _lap(what: String) -> void:
	var now:= Time.get_ticks_usec()
	var ms:= (now - _mark) / 1000.0
	_mark = now
	if ms >= SHOW_MS:
		print("[laps] frame %3d %6.0f ms  %s" % [_frame, ms, what])
