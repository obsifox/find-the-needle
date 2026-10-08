class_name Sketchbook
extends RefCounted


const PATH:= "user://sketchbook.dat"
const VERSION:= 1


const MAX_DRAWINGS:= 24


const MAX_STROKES:= 600
const MAX_POINTS:= 12000


static var _book: Array [Dictionary] = []
static var _loaded:= false


static var inert:= false:
	set(on):
		inert = on
		if on:


			_book = []
			_loaded = true


static func all() -> Array [Dictionary]:
	_ensure()
	return _book.duplicate()


static func count() -> int:
	_ensure()
	return _book.size()


static func at(i: int) -> Dictionary:
	_ensure()
	if i < 0 or i >= _book.size():
		return { }
	return _book [i]


static func keep(strokes: Array, title: String = "") -> int:
	_ensure()
	var clean:= _sanitise(strokes)
	if clean.is_empty():
		return -1
	var name:= title.strip_edges()
	if name.is_empty():
		name = Cfg.tr("Drawing %d") % (_book.size() + 1)
	_book.push_front({
		"name": name.substr(0, 40),
		"at": int(Time.get_unix_time_from_system()),
		"strokes": clean,
	})
	while _book.size() > MAX_DRAWINGS:
		_book.pop_back()
	_write()
	return 0


static func forget(i: int) -> void:
	_ensure()
	if i < 0 or i >= _book.size():
		return
	_book.remove_at(i)
	_write()


static func retitle(i: int, title: String) -> void:
	_ensure()
	if i < 0 or i >= _book.size():
		return
	var name:= title.strip_edges()
	if name.is_empty():
		return
	_book [i] ["name"] = name.substr(0, 40)
	_write()


static func strokes_of(i: int) -> Array:
	var d:= at(i)
	if d.is_empty():
		return []
	var out: Array = []
	for s: Dictionary in d.get("strokes", []):
		out.append({
			"t": int(s.get("t", 0)),
			"c": s.get("c", Color.BLACK) as Color,
			"w": float(s.get("w", 0.01)),
			"p": (s.get("p", PackedVector2Array()) as PackedVector2Array).duplicate(),
		})
	return out


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_book = []
	if not FileAccess.file_exists(PATH):
		return
	var f:= FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_warning("Sketchbook: cannot read %s" % PATH)
		return
	var raw: Variant = f.get_var()
	f.close()
	if typeof(raw) != TYPE_DICTIONARY:
		push_warning("Sketchbook: %s is not a book, starting an empty one" % PATH)
		return
	var d: Dictionary = raw


	for entry: Variant in d.get("drawings", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		var clean:= _sanitise(e.get("strokes", []))
		if clean.is_empty():
			continue
		_book.append({
			"name": str(e.get("name", Cfg.tr("Drawing"))).substr(0, 40),
			"at": int(e.get("at", 0)),
			"strokes": clean,
		})


static func _write() -> void:
	if inert:
		return
	var f:= FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Sketchbook: cannot write %s" % PATH)
		return
	f.store_var({ "version": VERSION, "drawings": _book })
	f.close()


static func _sanitise(strokes: Array) -> Array:
	var out: Array = []
	var points:= 0
	for entry: Variant in strokes:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = entry
		var p: Variant = s.get("p")
		if typeof(p) != TYPE_PACKED_VECTOR2_ARRAY:
			continue
		var pts: PackedVector2Array = p
		if pts.size() < 1:
			continue
		if out.size() >= MAX_STROKES or points + pts.size() > MAX_POINTS:
			break
		var clamped:= PackedVector2Array()
		clamped.resize(pts.size())
		for i in pts.size():
			clamped [i] = Vector2(clampf(pts [i].x, 0.0, 1.0),
				clampf(pts [i].y, 0.0, 1.0))
		points += clamped.size()
		out.append({
			"t": int(s.get("t", 0)),
			"c": s.get("c", Color.BLACK) as Color,
			"w": clampf(float(s.get("w", 0.01)), 0.001, 0.2),
			"p": clamped,
		})
	return out
