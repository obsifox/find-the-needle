class_name PowerBox
extends PowerPole


const BOX_MODEL:= "res://assets/models/cable_box.glb"
const BOX_SPEC:= "res://assets/models/cable_box_materials.json"


const BOX_WIRE_FALLBACK:= Vector3(0.0, 0.99, 0.0)


func model_path() -> String:
	return BOX_MODEL


func spec_path() -> String:
	return BOX_SPEC


func wire_fallback() -> Vector3:
	return BOX_WIRE_FALLBACK


func buried() -> bool:
	return true


func link_reach() -> float:
	return Tech.box_link_r()


func supply_reach() -> float:
	return Tech.box_supply_r()


func footprint() -> Vector2:
	return Vector2(0.5, 0.4)


func build_cost() -> float:
	return Cfg.BOX_COST


func to_dict() -> Dictionary:
	var d:= super.to_dict()
	d ["type"] = "power_box"
	return d


func connect_to(other: Node3D, settled: bool = false) -> PowerLine:
	var post:= other as PowerPole
	if post != null and post.buried():
		if _keep_trace(CableTrace.path(global_position, post.global_position)):
			return null
		var trace:= CableTrace.hang(self, global_position, post.global_position)
		_wires.append(trace)
		return null
	return super.connect_to(other, settled)


func connect_anchor(anchor: Node3D, _settled: bool = false) -> PowerLine:
	if anchor == null or not is_instance_valid(anchor):
		return null
	var port:= anchor.global_position
	var foot:= Vector3(port.x, global_position.y, port.z)
	if _keep_trace(CableTrace.path(global_position, foot, port)):
		return null
	var trace:= CableTrace.hang(self, global_position, foot, port)
	_wires.append(trace)
	return null


func _keep_trace(path: PackedVector3Array) -> bool:
	if not BuildManager.yard_memo_enabled:
		return false
	for i in _old_wires.size():
		var trace:= _old_wires [i] as CableTrace
		if trace != null and is_instance_valid(trace) and trace.points() == path:
			_old_wires.remove_at(i)
			_wires.append(trace)
			return true
	return false
