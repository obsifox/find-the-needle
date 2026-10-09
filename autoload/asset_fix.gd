extends Node

## V38 ASSET FALLBACK NET. The v1.3.0 tree ships 293 non-texture assets
## in GDRE-recovered form (source stripped, only compiled artefacts
## exist). Code now references the compiled artefacts directly; this
## autoload resolves any surviving or dynamically-built source path via
## remaps/remap_table.gd and reports anything that still fails, so a
## missing asset can never again reach RenderingServer as a silent null
## (the V36/V37 Mali death pattern).

var _table: Dictionary = {}
var _logged: Dictionary = {}


func _ready() -> void:
	var s: GDScript = load("res://remaps/remap_table.gd")
	if s != null:
		_table = s.table()
	print("[assetfix] remap table entries: %d" % _table.size())


func resolve(path: String) -> String:
	if _table.is_empty() or ResourceLoader.exists(path):
		return path
	var alt: String = String(_table.get(path, ""))
	if alt != "" and not _logged.has(path):
		_logged[path] = true
		print("[assetfix] %s -> %s" % [path, alt])
	return alt if alt != "" else path


func load_res(path: String, type_hint: String = "") -> Resource:
	var p := resolve(path)
	var res := ResourceLoader.load(p, type_hint)
	if res == null and not _logged.has("MISS:" + path):
		_logged["MISS:" + path] = true
		push_warning("[assetfix] UNRESOLVED: %s" % path)
	return res
