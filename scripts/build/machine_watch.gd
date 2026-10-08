class_name MachineWatch
extends Node


const POLL:= 0.25


const HOLD:= 4.0
const CLEAR:= 1.5


static var _old_watch: bool = "--oldwatch" in OS.get_cmdline_user_args()


var builds: BuildManager

var _timer:= 0.0


var _round: Array [Node3D] = []
var _round_next:= 0
var _round_step:= POLL
var _round_seen: Dictionary = { }


var _tracked: Dictionary = { }


func _process(delta: float) -> void:
	_timer -= delta
	if _old_watch:
		if _timer > 0.0:
			return
		var old_step:= POLL - _timer
		_timer = POLL
		if builds == null:
			return
		_sweep(old_step)
		return
	if _timer <= 0.0:
		var step:= POLL - _timer
		_timer = POLL
		_finish_round()
		if builds == null:
			return
		_round = _fleet()
		_round_next = 0
		_round_step = step
		_round_seen.clear()
	if builds == null:
		return
	var due:= ceili(float(_round.size()) * clampf(1.0 - _timer / POLL, 0.0, 1.0))
	_poll_round(due)


func _poll_round(until: int) -> void:
	until = mini(until, _round.size())
	while _round_next < until:


		var machine: Variant = _round [_round_next]
		_round_next += 1
		if not is_instance_valid(machine):
			continue
		_round_seen [(machine as Node3D).get_instance_id()] = true
		_poll(machine as Node3D, _round_step)


func _finish_round() -> void:
	if _round.is_empty():
		return
	_poll_round(_round.size())
	for id: int in _tracked.keys():
		if not _round_seen.has(id):
			_tracked.erase(id)
	_round.clear()


func alert_reason(machine: Node) -> String:
	if machine == null:
		return ""
	var entry: Dictionary = _tracked.get(machine.get_instance_id(), { })
	if entry.is_empty() or entry ["sign"] == null:
		return ""
	return str(entry ["reason"])


func alert_count() -> int:
	var n:= 0
	for entry: Dictionary in _tracked.values():
		if entry ["sign"] != null:
			n += 1
	return n


func force_sweep(step: float) -> void:
	if builds != null:
		_sweep(step)


func _sweep(step: float) -> void:
	var seen:= { }
	for machine in _fleet():
		if machine == null or not is_instance_valid(machine):
			continue
		seen [machine.get_instance_id()] = true
		_poll(machine, step)


	for id: int in _tracked.keys():
		if not seen.has(id):
			_tracked.erase(id)


func _fleet() -> Array [Node3D]:
	var out: Array [Node3D] = []
	for group: Array in [builds.piston_rakes, builds.robotic_arms, builds.scanners,
			builds.compressors, builds.pulpers, builds.papers,
			builds.briquette_presses, builds.wrappers, builds.silos,
			builds.pelletizers, builds.generators, builds.boreholes,
			builds.hay_drones, builds.tube_launchers]:
		for machine: Node3D in group:
			if machine != null and machine.has_method("alert_reason"):
				out.append(machine)
	return out


func _poll(machine: Node3D, step: float) -> void:
	var id:= machine.get_instance_id()
	var entry: Dictionary = _tracked.get(id, {
		"machine": machine, "reason": "", "held": 0.0, "clear": 0.0, "sign": null,
	})
	_tracked [id] = entry
	var reason:= str(machine.call("alert_reason"))

	if reason == "":
		entry ["held"] = 0.0
		if entry ["sign"] == null:
			return
		entry ["clear"] += step
		if entry ["clear"] >= CLEAR:
			_take_down(entry)
		return

	entry ["clear"] = 0.0
	var icon:= _icon_of(machine)


	if reason != entry ["reason"]:
		entry ["reason"] = reason
		if entry ["sign"] == null:
			entry ["held"] = 0.0


			if not _instant(icon):
				return
		else:


			(entry ["sign"] as MachineAlert).set_icon(icon)
	entry ["held"] += step
	if entry ["sign"] == null and (_instant(icon) or entry ["held"] >= HOLD):
		entry ["sign"] = MachineAlert.stand_over(machine, icon)


func _icon_of(machine: Node3D) -> String:
	if not machine.has_method("alert_icon"):
		return ""
	return str(machine.call("alert_icon"))


static func _instant(icon: String) -> bool:
	return icon == "power" or icon == "water" or icon == "jam"


func alert_icon(machine: Node) -> String:
	if machine == null:
		return ""
	var entry: Dictionary = _tracked.get(machine.get_instance_id(), { })
	if entry.is_empty() or entry ["sign"] == null:
		return ""
	return (entry ["sign"] as MachineAlert).icon()


func _take_down(entry: Dictionary) -> void:
	var sign_node: MachineAlert = entry ["sign"]
	entry ["sign"] = null
	entry ["reason"] = ""
	entry ["clear"] = 0.0
	if sign_node == null or not is_instance_valid(sign_node):
		return


	sign_node.retire()
