class_name PointIndex
extends RefCounted


const JOIN:= 0.01


const CELL:= 0.5


var _cells:= { }


func add(point: Vector3, value: Variant, rank: int) -> void:
	var key:= Vector3i(floori(point.x / CELL), floori(point.y / CELL),
		floori(point.z / CELL))
	var bucket: Array = _cells.get(key, [])
	if bucket.is_empty():
		_cells [key] = bucket
	bucket.append([point, value, rank])


func best(query: Vector3) -> Array:
	var out:= []
	for e: Array in _matching(query):
		if out.is_empty() or int(e [2]) < int(out [0]):
			out = [e [2], e [1]]
	return out


func all(query: Vector3) -> Array:
	var out:= _matching(query)
	if out.size() > 1:
		out.sort_custom(func(x: Array, y: Array) -> bool: return int(x [2]) < int(y [2]))
	return out


func within(query: Vector3, radius: float) -> Array:
	var out:= []
	var r2:= radius * radius
	for cx in range(floori((query.x - radius) / CELL), floori((query.x + radius) / CELL) + 1):
		for cy in range(floori((query.y - radius) / CELL), floori((query.y + radius) / CELL) + 1):
			for cz in range(floori((query.z - radius) / CELL), floori((query.z + radius) / CELL) + 1):
				var bucket: Variant = _cells.get(Vector3i(cx, cy, cz))
				if bucket == null:
					continue
				for e: Array in bucket:
					if (e [0] as Vector3).distance_squared_to(query) <= r2:
						out.append(e)
	if out.size() > 1:
		out.sort_custom(_nearer.bind(query))
	return out


func entries() -> Array:
	var out:= []
	for bucket: Array in _cells.values():
		out.append_array(bucket)
	return out


static func _nearer(a: Array, b: Array, q: Vector3) -> bool:
	return (a [0] as Vector3).distance_squared_to(q) < (b [0] as Vector3).distance_squared_to(q)


func _matching(query: Vector3) -> Array:
	var out:= []
	var rx:= _reach(query.x)
	var ry:= _reach(query.y)
	var rz:= _reach(query.z)
	for cx in range(floori((query.x - rx) / CELL), floori((query.x + rx) / CELL) + 1):
		for cy in range(floori((query.y - ry) / CELL), floori((query.y + ry) / CELL) + 1):
			for cz in range(floori((query.z - rz) / CELL), floori((query.z + rz) / CELL) + 1):
				var bucket: Variant = _cells.get(Vector3i(cx, cy, cz))
				if bucket == null:
					continue
				for e: Array in bucket:
					if joins(e [0] as Vector3, query):
						out.append(e)
	return out


static func joins(a: Vector3, b: Vector3) -> bool:
	return a.distance_squared_to(b) < JOIN * JOIN


static func _reach(_q: float) -> float:
	return JOIN * 1.5
