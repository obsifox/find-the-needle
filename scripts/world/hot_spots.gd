class_name HotSpots
extends RefCounted


static var on:= false
static var _us:= { }
static var _calls:= { }


static func start() -> void:
	_us.clear()
	_calls.clear()
	on = true


static func stop() -> void:
	on = false


static func add(key: StringName, since_usec: int) -> void:
	if not on:
		return
	add_usec(key, Time.get_ticks_usec() - since_usec)


static func add_usec(key: StringName, usec: int) -> void:
	if not on:
		return
	_us [key] = int(_us.get(key, 0)) + usec
	_calls [key] = int(_calls.get(key, 0)) + 1


static func total_ms(prefix: String, frames: int) -> float:
	var sum:= 0
	for key: StringName in _us:
		if String(key).begins_with(prefix):
			sum += int(_us [key])
	return sum / 1000.0 / maxi(1, frames)


static func lines(frames: int) -> PackedStringArray:
	var keys: Array = _us.keys()
	keys.sort_custom(func(a, b) -> bool: return int(_us [a]) > int(_us [b]))
	var out:= PackedStringArray()
	for key: StringName in keys:
		out.append("    %-34s %6.3f ms a frame, %5.2f calls a frame" % [key,
			int(_us [key]) / 1000.0 / maxi(1, frames), float(_calls [key]) / maxi(1, frames)])
	return out
