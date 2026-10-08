extends SceneTree


const LONGEST:= 8


func _init() -> void:
	var args:= OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: godot --headless --path . -s scripts/dev/print_diary.gd -- <save copy>")
		quit(1)
		return
	var d:= _read(args [0])
	if d.is_empty():
		print("could not read %s" % args [0])
		quit(1)
		return
	var state: Dictionary = d.get("state", { })
	var log: Array = state.get("purchase_log", [])
	if log.is_empty():
		print("no purchases in this save (it may be from before the diary existed)")
		quit(0)
		return
	print("%8s  %7s  %-6s %-26s %4s %10s" % ["clock", "wait", "kind", "what", "rank", "price"])
	var last:= 0.0
	var waits: Array = []
	for e: Variant in log:
		var row: Array = e
		var t:= float(row [0])
		var wait:= t - last
		last = t
		waits.append([wait, t, str(row [2])])
		print("%8s  %7s  %-6s %-26s %4s %10s" % [_clock(t), _clock(wait), str(row [1]),
			str(row [2]), ("r%d" % int(row [3])) if int(row [3]) > 0 else "",
			"$%.2f" % float(row [4])])
	waits.sort_custom(func(a: Array, b: Array) -> bool: return float(a [0]) > float(b [0]))
	print("\nlongest waits:")
	for i in mini(LONGEST, waits.size()):
		var w: Array = waits [i]
		print("  %7s  before %s at %s" % [_clock(float(w [0])), str(w [2]), _clock(float(w [1]))])
	print("\n%d purchases over %s of play" % [log.size(), _clock(float(state.get("run_secs", last)))])
	quit(0)


func _read(path: String) -> Dictionary:
	var f:= FileAccess.open(path, FileAccess.READ)
	if f == null:
		return { }
	if f.get_length() >= 4 and f.get_32() == 1128612935:
		f.close()
		f = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, _save_pass())
		if f == null:
			return { }
	else:
		f.seek(0)
	var v: Variant = f.get_var(true)
	f.close()
	return v if v is Dictionary else { }


func _save_pass() -> String:
	var here: String = (get_script() as Script).resource_path
	var root:= here.get_base_dir().get_base_dir().get_base_dir()
	var src:= FileAccess.get_file_as_string(root.path_join("autoload/save_manager.gd"))
	var re:= RegEx.create_from_string("const SAVE_PASS := \"([0-9a-f]+)\"")
	var m:= re.search(src)
	return m.get_string(1) if m != null else ""


static func _clock(secs: float) -> String:
	var s:= int(round(secs))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]
