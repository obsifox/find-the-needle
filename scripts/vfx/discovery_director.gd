class_name DiscoveryDirector
extends Node


var builds: BuildManager


var card: DiscoveryCard


func _ready() -> void:
	GameState.needle_discovered.connect(_on_discovered)


func _exit_tree() -> void:
	if GameState.needle_discovered.is_connected(_on_discovered):
		GameState.needle_discovered.disconnect(_on_discovered)


func _on_discovered(type: int, at: Vector3) -> void:
	if builds == null:
		return
	var cab:= builds.nearest_cabinet(at)
	if cab == null:


		return
	stage(type, at, cab)


func stage(type: int, at: Vector3, cab: NeedleCabinet) -> void:
	var target:= cab.slot_position(type)


	var from:= at + Vector3(0.0, 0.35, 0.0)
	var flight:= DiscoveryFlight.spawn(self, type, from, target, _tint(type))


	var id:= cab.get_instance_id()
	flight.arrived.connect(func(t: int) -> void:
		var target_cab:= instance_from_id(id) as NeedleCabinet
		if target_cab != null and target_cab.is_inside_tree():
			target_cab.reveal(t)


		if card != null and not GameState.collection_complete():
			card.play(t))


func _tint(type: int) -> Color:
	return NeedleCabinet.type_colour(type)
