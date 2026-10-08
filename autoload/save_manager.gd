extends Node


const SAVE_DIR:= "user://saves"
const SLOT_PATH:= "user://saves/slot_%d.dat"


const SLOT_FILE:= "slot_%d.dat"


const TEMP_SUFFIX:= ".tmp"
const BACKUP_SUFFIX:= ".bak"


const LEGACY_PATH:= "user://haystack_save.dat"


const SLOT_COUNT:= 100


const FORMAT_VERSION:= 11
const OLDEST_READABLE:= 1


const SAVE_PASS:= "b88b32d1fb83a23ac1facd11a612222774cca9aed41a87ed"


const ENCRYPTED_MAGIC:= 1128612935


const DEFAULT_MAP:= "warehouse"


const PILE_SHAPE_LEGACY:= 0
const PILE_SHAPE_SETTLED:= 1


const READ_EMPTY:= "empty"
const READ_OK:= "ok"
const READ_DAMAGED:= "damaged"
const READ_NEWER:= "newer"

signal saved()
signal loaded()


var current_slot:= 0


var current_map:= DEFAULT_MAP


var current_pile_size:= Cfg.DEFAULT_PILE_SIZE


var current_name:= ""


var current_locked:= false


var current_pile_shape_version:= PILE_SHAPE_SETTLED


const NAME_MAX_LEN:= 28


var _dir:= SAVE_DIR


var block_save:= false
var refuse_reason:= ""

var _pending_player_transform: Transform3D = Transform3D.IDENTITY
var has_pending_player_transform:= false
var _pending_buildings: Array = []
var _pending_props: Array = []


var _pending_belts: Dictionary = { }


var _pending_dome:= PackedFloat32Array()


var _fresh_start:= false

var _intro_due:= false


var _summary_cache:= { }


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	_migrate_legacy()


func use_scratch_dir(dir: String) -> String:
	_dir = dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	return _dir


func use_player_saves() -> void:
	_dir = SAVE_DIR


func save_dir() -> String:
	return _dir


func slot_path(slot: int) -> String:
	return "%s/%s" % [_dir, SLOT_FILE % clampi(slot, 0, SLOT_COUNT - 1)]


func backup_path(slot: int) -> String:
	return slot_path(slot) + BACKUP_SUFFIX


func has_save(slot: int = -1) -> bool:
	var s:= slot if slot >= 0 else current_slot
	return FileAccess.file_exists(slot_path(s)) or FileAccess.file_exists(backup_path(s))


func any_save() -> bool:
	for i in SLOT_COUNT:
		if has_save(i):
			return true
	return false


func next_free_slot() -> int:
	var last:= -1
	for i in SLOT_COUNT:
		if has_save(i):
			last = i
	if last + 1 < SLOT_COUNT:
		return last + 1
	for i in SLOT_COUNT:
		if not has_save(i):
			return i
	return -1


func begin_new_game(slot: int, ignore_lock: bool = false,
		map_id: String = DEFAULT_MAP,
		pile_size: String = Cfg.DEFAULT_PILE_SIZE) -> bool:
	var s:= clampi(slot, 0, SLOT_COUNT - 1)
	if not ignore_lock and is_locked(s):
		push_warning("SaveManager: slot %d is locked, not starting a new run in it" % s)
		return false
	current_slot = s
	current_map = map_id if map_id != "" else DEFAULT_MAP


	current_pile_size = pile_size if pile_size != "" else Cfg.DEFAULT_PILE_SIZE
	Cfg.apply_pile_size(current_pile_size)
	Cfg.shed_long_bays = Cfg.SHED_LONG_BAYS


	current_name = ""
	current_locked = false
	current_pile_shape_version = PILE_SHAPE_SETTLED
	_fresh_start = true
	_intro_due = true
	_clear_pending()
	_begin_run()
	return true


func begin_load(slot: int) -> void:
	current_slot = clampi(slot, 0, SLOT_COUNT - 1)


	var meta: Dictionary = _read(current_slot).get("meta", { })
	current_name = _clean_name(str(meta.get("name", "")))
	current_locked = bool(meta.get("locked", false))

	current_map = str(meta.get("map", DEFAULT_MAP))
	if current_map == "":
		current_map = DEFAULT_MAP


	current_pile_size = str(meta.get("pile_size", Cfg.DEFAULT_PILE_SIZE))
	if current_pile_size == "":
		current_pile_size = Cfg.DEFAULT_PILE_SIZE
	Cfg.apply_pile_size(current_pile_size)


	Cfg.shed_long_bays = int(meta.get("shed_bays", 0))
	_fresh_start = false
	_intro_due = false
	_clear_pending()
	_begin_run()


func _begin_run() -> void:

	block_save = false
	refuse_reason = ""
	Profile.begin_run()


func take_intro_due() -> bool:
	var due:= _intro_due
	_intro_due = false
	return due


func save_game(field_heights: PackedFloat32Array, player_xform: Transform3D,
		buildings: Array = [], props: Array = [],
		loose_strands: float = 0.0, belts: Dictionary = { },
		dome: PackedFloat32Array = PackedFloat32Array(), dome_seed: int = 0) -> bool:
	if block_save:


		return false
	var payload:= {
		"version": FORMAT_VERSION,
		"pile_shape_version": current_pile_shape_version,
		"state": GameState.to_dict(),
		"heights": field_heights,
		"player": player_xform,
		"buildings": buildings,
		"props": props,
		"belts": belts,
		"tech": Tech.to_dict(),
		"cell": Cfg.CELL,
		"extent": Cfg.FIELD_EXTENT,


		"meta": {
			"name": current_name,
			"locked": current_locked,
			"map": current_map,
			"pile_size": current_pile_size,


			"shed_bays": Cfg.shed_long_bays,
			"saved_at": int(Time.get_unix_time_from_system()),
			"hay_dug": GameState.hay_dug,
			"hay_initial": GameState.hay_initial,
			"hay_total": GameState.hay_total,
			"needles_found": GameState.needles_found,
			"money": GameState.money,
			"money_earned": GameState.money_earned,
		},
	}
	if not dome.is_empty() and dome.size() == field_heights.size():
		payload ["dome"] = dome
		payload ["dome_seed"] = dome_seed
	_credit_loose_strands(payload, loose_strands)
	if not _write_payload(current_slot, payload):
		return false


	_fresh_start = false
	saved.emit()
	return true


func _credit_loose_strands(payload: Dictionary, count: float) -> void:
	if count <= 0.0:
		return
	var state: Dictionary = payload.get("state", { })
	state ["hay_total"] = float(state.get("hay_total", 0.0)) + count


	state ["hay_returned"] = float(state.get("hay_returned", 0.0)) + count
	payload ["state"] = state
	var meta: Dictionary = payload.get("meta", { })
	meta ["hay_total"] = float(meta.get("hay_total", 0.0)) + count
	payload ["meta"] = meta


func load_game() -> PackedFloat32Array:

	_pending_dome = PackedFloat32Array()
	if _fresh_start:


		current_pile_shape_version = PILE_SHAPE_SETTLED
		_clear_pending()
		return PackedFloat32Array()
	var d:= _read(current_slot)
	if d.is_empty():
		current_pile_shape_version = PILE_SHAPE_SETTLED
		return PackedFloat32Array()


	if not _field_matches(d, Cfg.FIELD_EXTENT):
		_refuse("This save was made with a different pile size and cannot be opened by this build")
		current_pile_shape_version = PILE_SHAPE_SETTLED
		return PackedFloat32Array()
	current_pile_shape_version = int(d.get("pile_shape_version", PILE_SHAPE_LEGACY))
	GameState.from_dict(d.get("state", { }))
	_apply_tech(d)


	GameState.resolve_legacy_tools()
	_pending_player_transform = d.get("player", Transform3D.IDENTITY)
	has_pending_player_transform = true
	_pending_buildings = d.get("buildings", [])
	_pending_props = d.get("props", [])
	var belts: Variant = d.get("belts", { })
	_pending_belts = belts if belts is Dictionary else { }


	_pending_dome = PackedFloat32Array()
	var dome: Variant = d.get("dome", null)
	if dome is PackedFloat32Array and d.has("dome_seed") and int(d ["dome_seed"]) == GameState.run_seed:
		_pending_dome = dome
	loaded.emit()
	return d.get("heights", PackedFloat32Array())


func slot_summary(slot: int) -> Dictionary:
	var path:= slot_path(slot)
	var stamp:= "%s|%s" % [_file_stamp(path), _file_stamp(backup_path(slot))]
	var held: Dictionary = _summary_cache.get(path, { })
	if str(held.get("stamp", "")) == stamp:
		return held ["summary"]
	var fresh:= _build_summary(slot)
	_summary_cache [path] = { "stamp": stamp, "summary": fresh }
	return fresh


func _file_stamp(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f:= FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "?"
	var length:= f.get_length()
	f.close()
	return "%d:%d" % [FileAccess.get_modified_time(path), length]


func _forget_summary(slot: int) -> void:
	_summary_cache.erase(slot_path(slot))


func _build_summary(slot: int) -> Dictionary:
	var look:= _inspect(slot)
	var status: String = look ["status"]
	if status == READ_EMPTY:
		return { }
	if status != READ_OK:
		return {
			"readable": false,
			"status": status,
			"version": int(look.get("version", 0)),


			"backup": bool(look ["has_backup"]),
		}
	var d: Dictionary = look ["data"]
	var state: Dictionary = d.get("state", { })
	var meta: Dictionary = d.get("meta", { })
	var size_id:= str(meta.get("pile_size", Cfg.DEFAULT_PILE_SIZE))
	if size_id == "":
		size_id = Cfg.DEFAULT_PILE_SIZE


	var want_extent:= float(Cfg.pile_size_spec(size_id).get("extent", Cfg.FIELD_EXTENT))
	var initial: float = meta.get("hay_initial", state.get("hay_initial", 0.0))
	var dug: float = meta.get("hay_dug", state.get("hay_dug", 0.0))


	var total: float = meta.get("hay_total", state.get("hay_total", 0.0))
	return {
		"readable": true,
		"status": READ_OK,


		"from_backup": bool(look ["from_backup"]),


		"incompatible": not _field_matches(d, want_extent),
		"name": _clean_name(str(meta.get("name", ""))),
		"locked": bool(meta.get("locked", false)),
		"saved_at": int(meta.get("saved_at", 0)),
		"hay_dug": dug,
		"hay_initial": initial,
		"hay_total": total,
		"map": str(meta.get("map", DEFAULT_MAP)),
		"pile_size": str(meta.get("pile_size", Cfg.DEFAULT_PILE_SIZE)),
		"needles_found": int(meta.get("needles_found", state.get("needles_found", 0))),
		"money": float(meta.get("money", state.get("money", 0.0))),
		"money_earned": float(meta.get("money_earned", state.get("money_earned", 0.0))),


		"money_peak": maxf(float(state.get("money_peak", 0.0)),
			float(meta.get("money", state.get("money", 0.0)))),


		"first_needle_secs": (float(state.get("first_needle_secs", -1.0))
			if state.has("run_secs") and bool(state.get("run_timed", true)) else -1.0),


		"pile_clear_secs": (float(state.get("first_clear_secs", -1.0))
			if state.has("run_secs") and bool(state.get("run_timed", true)) else -1.0),
		"structures": structures_in(d.get("buildings", [])),
		"debug_used": bool(state.get("debug_used", false)),


		"run_secs": float(state.get("run_secs", 0.0)),


		"needles_stocked": _sum_of(state.get("needle_stock", PackedInt32Array())),
		"mission_index": int(state.get("mission_index", 0)),
		"contracts_done": _count_of(state.get("contracts_done", { })),
		"tech_ranks": _tech_ranks(d),
		"belt_metres": _belt_metres_in(d.get("buildings", [])),
	}


func _sum_of(v: Variant) -> int:
	var out:= 0
	if v is PackedInt32Array or v is Array:
		for n: Variant in v:
			out += int(n)
	return out


func _count_of(v: Variant) -> int:
	if v is Dictionary:
		return (v as Dictionary).size()
	if v is Array:
		return (v as Array).size()
	return 0


func _tech_ranks(d: Dictionary) -> int:
	var ranks: Variant = d.get("tech", { }).get("ranks", { })
	if not (ranks is Dictionary):
		return 0
	var out:= 0
	for id: Variant in ranks as Dictionary:
		if str(id) != TechTree.ROOT:
			out += maxi(int((ranks as Dictionary) [id]), 0)
	return out


static func _belt_metres_in(buildings: Array) -> float:
	var metres:= 0.0
	for b: Variant in buildings:
		if not (b is Dictionary):
			continue
		var row: Dictionary = b
		var kind:= str(row.get("type", ""))
		if kind != "conveyor" and kind != "enclosed_conveyor":
			continue
		var a: Variant = row.get("a", null)
		var z: Variant = row.get("b", null)
		if a is Vector3 and z is Vector3:
			metres += (a as Vector3).distance_to(z as Vector3)
	return metres


static func structures_in(buildings: Array) -> int:
	var count:= 0
	var lines:= { }
	for b: Variant in buildings:
		if not (b is Dictionary):
			continue
		var line:= int((b as Dictionary).get("line", 0))
		if line != 0:
			if lines.has(line):
				continue
			lines [line] = true
		count += 1
	return count


func _apply_tech(d: Dictionary) -> void:
	if int(d.get("version", 0)) >= 5 and d.has("tech"):
		Tech.from_dict(d.get("tech", { }), int(d.get("version", 0)) < 6)
	else:
		Tech.grant_legacy()


func take_player_transform() -> Transform3D:
	has_pending_player_transform = false
	return _pending_player_transform


func take_buildings() -> Array:
	var out:= _pending_buildings
	_pending_buildings = []
	return out


func take_props() -> Array:
	var out:= _pending_props
	_pending_props = []
	return out


func take_belts() -> Dictionary:
	var out:= _pending_belts
	_pending_belts = { }
	return out


func take_dome() -> PackedFloat32Array:
	var out:= _pending_dome
	_pending_dome = PackedFloat32Array()
	return out


func rename_save(slot: int, name: String) -> bool:
	var s:= clampi(slot, 0, SLOT_COUNT - 1)
	if is_locked(s):
		return false
	var clean:= _clean_name(name)
	if not _rewrite_meta(s, { "name": clean }, "rename"):
		return false


	if s == current_slot:
		current_name = clean
	return true


func is_locked(slot: int = -1) -> bool:
	var s:= slot if slot >= 0 else current_slot
	return bool(_read(s).get("meta", { }).get("locked", false))


func set_locked(slot: int, locked: bool) -> bool:
	var s:= clampi(slot, 0, SLOT_COUNT - 1)
	if not _rewrite_meta(s, { "locked": locked }, "lock"):
		return false
	if s == current_slot:
		current_locked = locked
	return true


func clean_name(name: String) -> String:
	return _clean_name(name)


func _clean_name(name: String) -> String:
	var out:= ""
	for c in name:

		out += c if c.unicode_at(0) >= 32 else " "
	out = out.strip_edges()
	return out.substr(0, NAME_MAX_LEN).strip_edges()


func delete_save(slot: int = -1) -> bool:
	var s:= slot if slot >= 0 else current_slot
	if is_locked(s):
		return false
	_forget_summary(s)
	_bin(slot_path(s))
	_bin(backup_path(s))


	if has_save(s):
		return false


	if s == current_slot:
		current_name = ""
		current_locked = false
	return true


func _read(slot: int) -> Dictionary:
	var look:= _inspect(slot)
	if look ["status"] != READ_OK:
		return { }
	if look ["from_backup"]:
		push_warning("SaveManager: %s could not be read; using the backup beside it"
			% slot_path(slot))
	return look ["data"]


func _inspect(slot: int) -> Dictionary:
	var main:= _read_file(slot_path(slot))
	var out:= {
		"status": main ["status"],
		"data": main ["data"],
		"version": main ["version"],
		"from_backup": false,


		"has_backup": FileAccess.file_exists(backup_path(slot)),
	}
	if main ["status"] == READ_OK or main ["status"] == READ_NEWER:
		return out
	var backup:= _read_file(backup_path(slot))
	if backup ["status"] == READ_OK:
		out ["status"] = READ_OK
		out ["data"] = backup ["data"]
		out ["version"] = backup ["version"]
		out ["from_backup"] = true
	elif main ["status"] == READ_EMPTY and backup ["status"] != READ_EMPTY:


		out ["status"] = backup ["status"]
		out ["version"] = backup ["version"]
	return out


func _read_file(path: String) -> Dictionary:
	var nothing:= { "status": READ_EMPTY, "data": { }, "version": 0 }
	if not FileAccess.file_exists(path):
		return nothing
	var f:= open_for_read(path)
	if f == null:
		return { "status": READ_DAMAGED, "data": { }, "version": 0 }
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		push_warning("SaveManager: %s is malformed" % path)
		return { "status": READ_DAMAGED, "data": { }, "version": 0 }
	var d: Dictionary = payload
	var version: int = d.get("version", 0)
	if version > FORMAT_VERSION:


		push_warning("SaveManager: %s was written by a newer build (version %d, this build reads %d)"
			% [path, version, FORMAT_VERSION])
		return { "status": READ_NEWER, "data": { }, "version": version }
	if version < OLDEST_READABLE:
		push_warning("SaveManager: %s has an unreadable version (%d)" % [path, version])
		return { "status": READ_DAMAGED, "data": { }, "version": version }
	return { "status": READ_OK, "data": d, "version": version }


func open_for_read(path: String) -> FileAccess:
	var f:= FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	if f.get_length() < 4 or f.get_32() != ENCRYPTED_MAGIC:
		f.seek(0)
		return f
	f.close()
	return FileAccess.open_encrypted_with_pass(path, FileAccess.READ, SAVE_PASS)


func _field_matches(d: Dictionary, extent: float) -> bool:
	return is_equal_approx(d.get("cell", -1.0), Cfg.CELL) and is_equal_approx(d.get("extent", -1.0), extent)


func _refuse(why: String) -> void:
	refuse_reason = why
	block_save = true
	push_error("SaveManager: refusing slot %d. %s" % [current_slot + 1, why])


func _bin(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var err:= OS.move_to_trash(ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("SaveManager: could not put %s in the recycle bin (%d)" % [path, err])


func _write_payload(slot: int, payload: Dictionary) -> bool:
	var path:= slot_path(slot)
	var temp:= path + TEMP_SUFFIX


	_forget_summary(slot)
	var f:= FileAccess.open_encrypted_with_pass(temp, FileAccess.WRITE, SAVE_PASS)
	if f == null:
		push_error("SaveManager: cannot open %s for write (%d)"
			% [temp, FileAccess.get_open_error()])
		return false
	f.store_var(payload, true)
	var err:= f.get_error()
	f.close()
	if err != OK:
		push_error("SaveManager: writing %s failed (%d); the save was left alone" % [temp, err])
		_bin(temp)
		return false


	var check:= FileAccess.open(temp, FileAccess.READ)
	var written: int = check.get_length() if check != null else 0
	if check != null:
		check.close()
	if written == 0:
		push_error("SaveManager: %s came out empty; the save was left alone" % temp)
		_bin(temp)
		return false


	var back:= open_for_read(temp)
	if back == null:
		push_error("SaveManager: %s does not read back; the save was left alone" % temp)
		_bin(temp)
		return false
	back.close()
	if FileAccess.file_exists(path):
		var moved:= DirAccess.rename_absolute(
			ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(path + BACKUP_SUFFIX))
		if moved != OK:
			push_error("SaveManager: cannot move %s aside (%d); the save was left alone"
				% [path, moved])
			_bin(temp)
			return false
	var placed:= DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp),
		ProjectSettings.globalize_path(path))
	if placed != OK:
		push_error("SaveManager: cannot move %s into place (%d). The previous save is in %s"
			% [temp, placed, path + BACKUP_SUFFIX])
		return false
	return true


func _rewrite_meta(slot: int, changes: Dictionary, what: String) -> bool:
	var d:= _read(slot)
	if d.is_empty():
		return false
	var meta: Dictionary = d.get("meta", { })
	for key in changes:
		meta [key] = changes [key]
	d ["meta"] = meta


	if not _write_payload(slot, d):
		push_error("SaveManager: could not %s slot %d" % [what, slot + 1])
		return false
	return true


func _clear_pending() -> void:
	has_pending_player_transform = false
	_pending_player_transform = Transform3D.IDENTITY
	_pending_buildings = []
	_pending_props = []
	_pending_belts = { }
	_pending_dome = PackedFloat32Array()


func _migrate_legacy() -> void:
	if not FileAccess.file_exists(LEGACY_PATH):
		return
	var dest:= slot_path(0)
	if FileAccess.file_exists(dest):
		return
	var src:= FileAccess.open(LEGACY_PATH, FileAccess.READ)
	if src == null:
		return
	var bytes:= src.get_buffer(src.get_length())
	src.close()
	var dst:= FileAccess.open(dest, FileAccess.WRITE)
	if dst == null:
		return
	dst.store_buffer(bytes)
	dst.close()
	print("[save] migrated the single-file save into slot 1")
