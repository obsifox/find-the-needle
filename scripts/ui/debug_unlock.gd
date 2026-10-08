class_name DebugUnlock
extends Node


const SEQUENCE: Array [int] = [
	KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN,
	KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT,
]


signal unlocked


var _recent: Array [int] = []


func _unhandled_input(event: InputEvent) -> void:


	if Cfg.debug_on():
		return

	var key:= event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return


	if not feed(key.keycode):
		return

	set_process_unhandled_input(false)
	unlocked.emit()


func feed(code: int) -> bool:
	_recent.append(code)
	if _recent.size() > SEQUENCE.size():
		_recent.remove_at(0)
	if _recent != SEQUENCE:
		return false
	_recent.clear()
	return true


func progress() -> int:
	for start: int in range(_recent.size()):
		var tail:= _recent.slice(start)
		if tail == SEQUENCE.slice(0, tail.size()):
			return tail.size()
	return 0
