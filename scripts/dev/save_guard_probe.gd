class_name DevSaveGuardProbe
extends Node


const SCRATCH_DIR:= "user://probe_saves/saveguard"


const SLOT:= 3

var world: Node3D

var _fails:= 0


var _kept_pile_size:= ""


func run() -> void:
	call_deferred("_run")


func _run() -> void:


	world.block_save = true
	if not _enter_scratch():
		get_tree().quit(1)
		return

	_case_damaged_offers_the_backup()
	_case_encrypted_and_plain()
	_case_real_copies()
	_case_newer_is_not_damaged()
	_case_extent_mismatch_refuses()
	await _case_needle_round_trip()
	await _case_belts_round_trip()
	_case_dome_round_trip()
	_case_save_before_built()
	_case_career_baseline()
	_case_career_waits_for_the_yard()
	_case_structures_net()
	_case_career_rebuilt_from_saves()

	_leave_scratch()
	print("\n[saveguard] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	print("  FAIL  %s" % msg)
	_fails += 1


func _check(ok: bool, what: String) -> bool:
	if ok:
		print("  ok    %s" % what)
	else:
		_fail(what)
	return ok


func _enter_scratch() -> bool:
	_kept_pile_size = Cfg.pile_size_id
	var dir:= SaveManager.use_scratch_dir(SCRATCH_DIR)
	var path:= SaveManager.slot_path(SLOT)
	if dir != SCRATCH_DIR or not path.begins_with(SCRATCH_DIR):
		push_error("[saveguard] the scratch redirect did not take (slot %d is %s); refusing to run"
			% [SLOT + 1, path])
		return false
	if path.begins_with(SaveManager.SAVE_DIR):
		push_error("[saveguard] the scratch path is inside the player's saves; refusing to run")
		return false
	print("[saveguard] every file is under %s. No slot is read or written." % dir)
	SaveManager.current_slot = SLOT
	_wipe()
	return true


func _leave_scratch() -> void:
	Cfg.apply_pile_size(_kept_pile_size)
	SaveManager.use_player_saves()


func _wipe() -> void:
	for p: String in [SaveManager.slot_path(SLOT), SaveManager.backup_path(SLOT),
			SaveManager.slot_path(SLOT) + SaveManager.TEMP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write_a_run(run_name: String) -> PackedByteArray:
	SaveManager.current_name = run_name
	SaveManager.current_locked = false
	SaveManager.block_save = false
	SaveManager.save_game(PackedFloat32Array(), Transform3D.IDENTITY)
	return _bytes(SaveManager.slot_path(SLOT))


func _truncate(path: String) -> void:
	var f:= FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_fail("could not write the damaged file at %s" % path)
		return
	f.store_8(31)
	f.store_8(139)
	f.close()


func _bytes(path: String) -> PackedByteArray:
	var f:= FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var b:= f.get_buffer(f.get_length())
	f.close()
	return b


func _put(path: String, payload: Dictionary) -> void:
	var f:= FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_fail("could not write %s" % path)
		return
	f.store_var(payload, true)
	f.close()


func _case_damaged_offers_the_backup() -> void:
	print("\n=== a damaged slot ===")
	_wipe()
	_truncate(SaveManager.slot_path(SLOT))
	var s:= SaveManager.slot_summary(SLOT)
	_check(SaveManager.has_save(SLOT), "a damaged file is still a full slot")
	_check(not s.get("readable", false), "...and does not read")
	_check(str(s.get("status", "")) == SaveManager.READ_DAMAGED,
		"...and is labelled damaged, with no backup to offer")
	_check(SaveManager.load_game().is_empty(), "...and loads as nothing")


	_wipe()
	_write_a_run("First write")
	_write_a_run("Second write")
	_check(FileAccess.file_exists(SaveManager.backup_path(SLOT)),
		"a second save leaves the first beside it as a backup")


	_write_a_run("Third write")
	_check(str(SaveManager.slot_summary(SLOT).get("name", "")) == "Third write",
		"a third save rotates over the backup that is already there")
	_write_a_run("First write")
	_write_a_run("Second write")
	var good:= _bytes(SaveManager.backup_path(SLOT))
	_truncate(SaveManager.slot_path(SLOT))
	s = SaveManager.slot_summary(SLOT)
	_check(s.get("readable", false), "a damaged slot with a backup reads again")
	_check(s.get("from_backup", false), "...and says the line came out of the backup")
	_check(str(s.get("name", "")) == "First write",
		"...and it is the run from one write ago")
	_check(_bytes(SaveManager.backup_path(SLOT)) == good,
		"...and reading it did not disturb the backup")


func _case_encrypted_and_plain() -> void:
	print("\n=== encrypted slots, and the plain ones from before ===")
	_wipe()
	var written:= _write_a_run("Locked run")
	_check(written.size() > 4 and written.decode_u32(0) == SaveManager.ENCRYPTED_MAGIC,
		"a slot is written encrypted")
	_check(not _contains(written, "Locked run".to_utf8_buffer()),
		"...and the run's name is not in it as text")
	var s:= SaveManager.slot_summary(SLOT)
	_check(s.get("readable", false) and str(s.get("name", "")) == "Locked run",
		"...and reads back")


	var f:= SaveManager.open_for_read(SaveManager.slot_path(SLOT))
	var d: Dictionary = f.get_var(true) if f != null else { }
	if f != null:
		f.close()
	var meta: Dictionary = d.get("meta", { })
	meta ["name"] = "Old plain run"
	d ["meta"] = meta
	_wipe()
	_put(SaveManager.slot_path(SLOT), d)
	SaveManager._forget_summary(SLOT)
	var plain:= _bytes(SaveManager.slot_path(SLOT))
	_check(plain.decode_u32(0) != SaveManager.ENCRYPTED_MAGIC
			and _contains(plain, "Old plain run".to_utf8_buffer()),
		"an old plain save is plain on disk")
	s = SaveManager.slot_summary(SLOT)
	_check(s.get("readable", false) and str(s.get("name", "")) == "Old plain run",
		"...and still loads")
	_check(not SaveManager._read(SLOT).is_empty(), "...all of it, not just the menu line")
	_write_a_run("Old plain run")
	_check(_bytes(SaveManager.slot_path(SLOT)).decode_u32(0) == SaveManager.ENCRYPTED_MAGIC,
		"its next save is encrypted")
	_check(_bytes(SaveManager.backup_path(SLOT)) == plain,
		"...and the plain file is kept, untouched, as the backup")


	_wipe()
	_write_a_run("Before the edit")
	_write_a_run("Edited run")
	var bytes:= _bytes(SaveManager.slot_path(SLOT))
	var at:= bytes.size() / 2
	bytes [at] = bytes [at] ^ 90
	var w:= FileAccess.open(SaveManager.slot_path(SLOT), FileAccess.WRITE)
	w.store_buffer(bytes)
	w.close()
	SaveManager._forget_summary(SLOT)
	_check(SaveManager.open_for_read(SaveManager.slot_path(SLOT)) == null,
		"an edited slot does not open")
	s = SaveManager.slot_summary(SLOT)
	_check(s.get("readable", false) and s.get("from_backup", false)
			and str(s.get("name", "")) == "Before the edit",
		"...so the backup answers for it, one write older")


func _case_real_copies() -> void:
	var ua:= OS.get_cmdline_user_args()
	var at:= ua.find("--copies")
	if at < 0 or at + 1 >= ua.size():
		return
	var dir: String = ua [at + 1]
	if ProjectSettings.globalize_path(dir).begins_with(
			ProjectSettings.globalize_path(SaveManager.SAVE_DIR)):
		_fail("--copies points into the player's saves; refusing to read it")
		return
	print("\n=== real save copies from %s ===" % dir)
	var done:= 0
	for n: String in DirAccess.get_files_at(dir):
		if not n.ends_with(".dat"):
			continue
		var src:= dir.path_join(n)
		var f:= SaveManager.open_for_read(src)
		var d: Variant = f.get_var(true) if f != null else null
		if f != null:
			f.close()
		if not d is Dictionary:
			_fail("%s did not read" % n)
			continue
		var before:= var_to_bytes_with_objects(d)
		_wipe()
		if not SaveManager._write_payload(SLOT, d):
			_fail("%s did not write" % n)
			continue
		var on_disk:= _bytes(SaveManager.slot_path(SLOT))
		var back:= SaveManager._read_file(SaveManager.slot_path(SLOT))
		var same: bool = back ["status"] == SaveManager.READ_OK and var_to_bytes_with_objects(back ["data"]) == before
		_check(same and on_disk.decode_u32(0) == SaveManager.ENCRYPTED_MAGIC,
			"%s: %d KB in, encrypted, read back identical" % [n, before.size() / 1024])
		done += 1
	_check(done > 0, "%d real saves went through" % done)


func _contains(hay: PackedByteArray, needle: PackedByteArray) -> bool:
	if needle.is_empty() or hay.size() < needle.size():
		return false
	var first:= needle [0]
	var i:= hay.find(first)
	while i >= 0 and i + needle.size() <= hay.size():
		if hay.slice(i, i + needle.size()) == needle:
			return true
		i = hay.find(first, i + 1)
	return false


func _case_newer_is_not_damaged() -> void:
	print("\n=== a save from a newer build ===")
	_wipe()
	_write_a_run("Tomorrow")
	var d:= { }
	var f:= SaveManager.open_for_read(SaveManager.slot_path(SLOT))
	if f != null:
		d = f.get_var(true)
		f.close()
	d ["version"] = SaveManager.FORMAT_VERSION + 1
	_put(SaveManager.slot_path(SLOT), d)
	var s:= SaveManager.slot_summary(SLOT)
	_check(not s.get("readable", false), "a newer save does not load in this build")
	_check(str(s.get("status", "")) == SaveManager.READ_NEWER,
		"...and is labelled newer rather than damaged")
	_check(str(s.get("status", "")) != SaveManager.READ_DAMAGED,
		"...so the row cannot offer ERASE for it")
	_check(int(s.get("version", 0)) == SaveManager.FORMAT_VERSION + 1,
		"...and says which version wrote it")


func _case_extent_mismatch_refuses() -> void:
	print("\n=== a save made at another pile size ===")
	_wipe()
	_write_a_run("Mountain run")
	var d:= { }
	var f:= SaveManager.open_for_read(SaveManager.slot_path(SLOT))
	if f != null:
		d = f.get_var(true)
		f.close()
	d ["extent"] = Cfg.FIELD_EXTENT + 7.0
	_put(SaveManager.slot_path(SLOT), d)

	_wipe_backup()
	var before:= _bytes(SaveManager.slot_path(SLOT))

	var s:= SaveManager.slot_summary(SLOT)
	_check(s.get("readable", false), "the file itself is perfectly readable")
	_check(s.get("incompatible", false),
		"...and the slot line says this build cannot open it")


	SaveManager.begin_load(SLOT)
	GameState.money = 4242.0
	var heights:= SaveManager.load_game()
	_check(heights.is_empty(), "the load comes back with no heights")
	_check(SaveManager.block_save, "...and saving is off for the rest of the session")
	_check(SaveManager.refuse_reason != "", "...with a sentence to show the player")
	_check(is_equal_approx(GameState.money, 4242.0),
		"...and the run state was not replaced by a fresh one")

	_check(not SaveManager.save_game(PackedFloat32Array(), Transform3D.IDENTITY),
		"a refused session refuses to write")
	_check(_bytes(SaveManager.slot_path(SLOT)) == before,
		"...and the file on disk is byte for byte what it was")
	print("  refusal: %s" % SaveManager.refuse_reason)


func _wipe_backup() -> void:
	var p:= SaveManager.backup_path(SLOT)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _case_needle_round_trip() -> void:
	print("\n=== a needle carried through a save ===")
	_wipe()


	SaveManager.begin_new_game(SLOT, true)
	await get_tree().process_frame

	var at:= Vector3(2.0, 0.5, 2.0)
	var type:= 0


	GameState.deposit_needle(GameState.register_needle(at, null, type), at)
	var found:= GameState.needles_found
	var stock:= GameState.stock_of(type)
	var ever: int = GameState.needles_by_type [type]

	var index:= GameState.withdraw_needle(type, at)
	_check(index >= 0, "a needle comes back out of the drawers")
	_check(GameState.stock_of(type) == stock - 1, "...and the drawer is one lighter")


	GameState.needle_loose = PackedInt32Array([index])
	GameState.needle_loose_at = PackedVector3Array([at])

	SaveManager.block_save = false
	SaveManager.current_name = "Carrying one"
	_check(SaveManager.save_game(PackedFloat32Array(), Transform3D.IDENTITY),
		"the run saves with the needle out")

	SaveManager.begin_load(SLOT)
	SaveManager.load_game()
	_check(GameState.needles_found == found,
		"a load finds nothing it had not already found")
	_check(GameState.stock_of(type) == stock - 1,
		"...and does not quietly refund the needle that is still out")
	_check(GameState.needle_out.has(index),
		"...and remembers that it is out, so putting it back is a return")
	_check(GameState.needle_loose.has(index),
		"...and the world has it on the list to put back on the floor")

	GameState.deposit_needle(index, at)
	_check(GameState.needles_found == found,
		"putting it back is not a find")
	_check(GameState.stock_of(type) == stock,
		"...the drawer is where it started")
	_check(GameState.needles_by_type [type] == ever,
		"...and the lifetime ledger never moved")


func _case_dome_round_trip() -> void:
	print("\n-- the starting pile rides in the save")
	_wipe()
	var n:= 64
	var heights:= PackedFloat32Array()
	heights.resize(n)
	var dome:= PackedFloat32Array()
	dome.resize(n)
	for k in n:
		heights [k] = 0.5 * float(k % 7)
		dome [k] = 1.0 + 0.25 * float(k % 5)
	SaveManager.block_save = false
	SaveManager.current_name = "Dome"
	GameState.run_seed = 4321

	_check(SaveManager.save_game(heights, Transform3D.IDENTITY, [], [], 0.0, { }, dome, 4321),
		"a run saves with its dome")
	var d: Dictionary = SaveManager._read_file(SaveManager.slot_path(SLOT)) ["data"]
	_check(d.get("version", 0) == SaveManager.FORMAT_VERSION,
		"...at the same format version, so an older build still opens it")
	SaveManager.begin_load(SLOT)
	_check(SaveManager.load_game() == heights, "the heights come back as they went")
	_check(SaveManager.take_dome() == dome, "...and the dome beside them")
	_check(SaveManager.take_dome().is_empty(), "...once")


	SaveManager.block_save = false
	SaveManager.save_game(heights, Transform3D.IDENTITY, [], [], 0.0, { }, dome, 999)
	SaveManager.begin_load(SLOT)
	SaveManager.load_game()
	_check(SaveManager.take_dome().is_empty(), "a dome shaped from another seed is not handed on")


	SaveManager.block_save = false
	var short:= dome.duplicate()
	short.resize(n - 1)
	SaveManager.save_game(heights, Transform3D.IDENTITY, [], [], 0.0, { }, short, 4321)
	d = SaveManager._read_file(SaveManager.slot_path(SLOT)) ["data"]
	_check(not d.has("dome") and not d.has("dome_seed"),
		"a dome of the wrong size is left out of the file")


	SaveManager.block_save = false
	SaveManager.save_game(heights, Transform3D.IDENTITY)
	SaveManager.begin_load(SLOT)
	_check(SaveManager.load_game() == heights, "a save with no dome still loads its heights")
	_check(SaveManager.take_dome().is_empty(), "...and hands on no dome")


	SaveManager.block_save = false
	SaveManager.save_game(heights, Transform3D.IDENTITY, [], [], 0.0, { }, dome, 4321)
	SaveManager.begin_load(SLOT)
	SaveManager.load_game()
	_wipe()
	SaveManager.load_game()
	_check(SaveManager.take_dome().is_empty(), "an empty slot hands on no dome left from the last load")
	SaveManager.block_save = true


func _case_belts_round_trip() -> void:
	print("\n=== the loads riding a belt, through a save ===")
	_wipe()
	SaveManager.begin_new_game(SLOT, true)
	await get_tree().process_frame
	var builds: BuildManager = world.builds
	var props: PropManager = world.props
	var head:= Vector3(13.6, 0.51, -6.0)
	var run: Conveyor = builds.add_conveyor(head, head + Vector3(0.0, 0.0, 6.0))
	if not _check(run != null, "a run is laid to ride"):
		return
	await get_tree().physics_frame


	var pushed:= 0
	for j in 6:
		var at:= head + Vector3(0.0, 0.0, 5.0 - 0.8 * float(j))
		if run.push_record(BeltRun.Kind.WAD, 60, -1, { "strands": 60 }, at, 0.0) >= 0:
			pushed += 1
	_check(pushed == 6, "six wads ride the run as records (%d)" % pushed)
	var section: Dictionary = world._belts_to_dict()
	var paths: Array = section.get("paths", [])
	_check(paths.size() == 1 and (paths [0] as Dictionary).get("records", []).size() == 6,
		"the section names one path carrying six")
	SaveManager.block_save = false
	SaveManager.current_name = "Six riding"
	_check(SaveManager.save_game(PackedFloat32Array(), Transform3D.IDENTITY,
		builds.to_array(), props.to_array(), 0.0, section), "the run saves with them riding")

	SaveManager.begin_load(SLOT)
	SaveManager.load_game()
	var saved_buildings:= SaveManager.take_buildings()
	var saved_props:= SaveManager.take_props()
	_check(saved_props.is_empty(), "no riding load is in the props list")
	_check(SaveManager._pending_belts.get("paths", []).size() == 1,
		"the belts section came back off the file")


	await builds.from_array(saved_buildings)
	props.from_array(saved_props)
	world._restore_belts()
	_check(SaveManager.take_belts().is_empty(), "...and the world's restore took it")
	run = builds.conveyors [0] if not builds.conveyors.is_empty() else null
	if not _check(run != null, "the run came back"):
		return
	_check(run.run.count() == 6, "all six are back on the run as records (%d)" % run.run.count())
	_check(props.items.is_empty(), "...and none as a body lying on the deck (%d)"
		% props.items.size())
	_check(BeltPath.belt_load() == 6, "belt_load reads 6 before a tick has run (%d)"
		% BeltPath.belt_load())
	var front:= run.run.first()
	var s0:= run.run.s_of(front)
	for i in 30:
		await get_tree().physics_frame
	_check(BeltPath.belt_load() == 6, "...and 6 on the ticks after")
	_check(run.run.count() == 6 and run.run.s_of(run.run.first()) > s0 + 0.1,
		"the belt is carrying them again (front from %.2f to %.2f m)"
		% [s0, run.run.s_of(run.run.first())])


	var lying: Array = []
	for i in range(run.run.first(), run.run.first() + run.run.count()):
		lying.append({ "id": "hay_wad", "xform": run.run.pose_of(i), "state": { "strands": 60 } })
	await builds.from_array(saved_buildings)
	props.from_array(lying)
	run = builds.conveyors [0] if not builds.conveyors.is_empty() else null
	for i in 90:
		await get_tree().physics_frame
	var caught:= run.run.count() if run != null else 0
	_check(caught + props.items.size() == 6 and caught >= 4,
		"an old file's loads are caught off the deck (%d riding, %d loose)"
		% [caught, props.items.size()])


	await builds.from_array([])
	props.from_array([])


func _case_save_before_built() -> void:
	print("\n=== the close button, mid build ===")
	_wipe()
	var path:= SaveManager.slot_path(SLOT)


	if not path.begins_with(SCRATCH_DIR):
		_fail("the slot path is not in the scratch directory; skipped the case")
		return
	world.block_save = false
	SaveManager.block_save = false

	world.set("_built", false)
	var refused: bool = world.call("save_now")
	_check(not refused, "save_now refuses while the yard is still being restored")
	_check(not FileAccess.file_exists(path), "...and nothing at all was written")


	world.set("_built", true)
	var wrote: bool = world.call("save_now")
	_check(wrote, "...and writes once the build has finished")
	_check(FileAccess.file_exists(path), "...leaving a file behind")

	world.block_save = true
	SaveManager.block_save = false


func _case_career_baseline() -> void:
	print("\n=== the career on a slot change ===")
	var seen: Dictionary = Profile.get("_seen")
	Profile.begin_run()
	var was:= Profile.hay_dug
	Profile.call("_accumulate", "hay_dug", 500.0)
	_check(is_equal_approx(Profile.hay_dug, was),
		"the first look at a run credits nothing, it only baselines")
	Profile.call("_accumulate", "hay_dug", 600.0)
	_check(is_equal_approx(Profile.hay_dug, was + 100.0),
		"...and what the run digs after that is credited")

	was = Profile.hay_dug
	SaveManager.begin_load(SLOT)
	_check(seen.is_empty(), "beginning a load clears what the last run was seen at")
	Profile.call("_accumulate", "hay_dug", 900000.0)
	_check(is_equal_approx(Profile.hay_dug, was),
		"...so the next run's totals are baselined rather than credited")

	Profile.call("_accumulate", "hay_dug", 900100.0)
	was = Profile.hay_dug
	SaveManager.begin_new_game(SLOT, true)
	_check(seen.is_empty(), "starting a new game clears it too")
	Profile.call("_accumulate", "hay_dug", 900200.0)
	_check(is_equal_approx(Profile.hay_dug, was),
		"...so a new game credits nothing it did not dig")


func _case_career_waits_for_the_yard() -> void:
	print("\n=== the career across a load ===")
	var kept_hay:= GameState.hay_dug
	var kept_earned:= GameState.money_earned
	var kept_needles:= GameState.needles_found


	Profile.leave_yard()
	GameState.hay_dug = 0.0
	GameState.money_earned = 0.0
	GameState.needles_found = 0
	SaveManager.begin_load(SLOT)
	var was_hay:= Profile.hay_dug
	var was_earned:= Profile.money_earned
	var was_needles:= Profile.needles_found


	Profile.call("_poll_run")

	GameState.hay_dug = 750000.0
	GameState.money_earned = 12000.0
	GameState.needles_found = 9
	Profile.call("_poll_run")
	_check(is_equal_approx(Profile.hay_dug, was_hay)
		and is_equal_approx(Profile.money_earned, was_earned)
		and Profile.needles_found == was_needles,
		"a poll between announcing a load and the yard being built credits nothing")

	Profile.enter_yard()
	Profile.call("_poll_run")
	_check(is_equal_approx(Profile.hay_dug, was_hay)
		and is_equal_approx(Profile.money_earned, was_earned)
		and Profile.needles_found == was_needles,
		"...and entering the yard baselines on the loaded figures instead of crediting them")

	GameState.hay_dug += 40.0
	GameState.needles_found += 1
	Profile.call("_poll_run")
	_check(is_equal_approx(Profile.hay_dug, was_hay + 40.0)
		and Profile.needles_found == was_needles + 1,
		"...while what the yard digs and finds after that is credited")


	Profile.leave_yard()
	GameState.hay_dug = 700000.0
	Profile.call("_poll_run")
	Profile.enter_yard()
	Profile.call("_poll_run")
	_check(is_equal_approx(Profile.hay_dug, was_hay + 40.0),
		"a quick load back to an older save neither credits nor takes anything away")

	_check(not Profile.play_time_counts(false, false, true),
		"no time played on the title screen")
	_check(Profile.play_time_counts(true, false, true), "...time played in a yard")
	_check(not Profile.play_time_counts(true, true, true), "...but not while paused")
	_check(not Profile.play_time_counts(true, false, false), "...or while unfocused")

	GameState.hay_dug = kept_hay
	GameState.money_earned = kept_earned
	GameState.needles_found = kept_needles


	Profile.enter_yard()


func _case_structures_net() -> void:
	print("\n=== structures built, placed and lifted ===")
	var kept:= Profile.structures_built
	var builds: Node = world.get("builds")
	if builds == null:
		_fail("the world has no BuildManager to demolish through")
		return

	Profile.structures_built = 5
	Profile.note_structure_built()
	var belt: Node3D = builds.call("add_conveyor",
		Vector3(40.0, 0.0, 40.0), Vector3(42.0, 0.0, 40.0), 0)
	builds.call("demolish", belt)
	_check(Profile.structures_built == 5,
		"placing a belt and lifting it straight back up leaves the count where it was, not %d"
		% Profile.structures_built)

	Profile.structures_built = 0
	Profile.note_structure_removed()
	_check(Profile.structures_built == 0,
		"lifting a structure the career never counted cannot take it below zero")

	Profile.structures_built = kept


func _case_career_rebuilt_from_saves() -> void:
	print("\n=== the career rebuilt from the saves ===")
	var kept_state:= [GameState.hay_dug, GameState.money_earned, GameState.needles_found,
		GameState.money, GameState.money_peak, GameState.run_secs, GameState.run_timed,
		GameState.first_needle_secs, GameState.debug_used]
	var kept_career:= [Profile.hay_dug, Profile.money_earned, Profile.needles_found,
		Profile.money_peak, Profile.structures_built, Profile.first_needle_secs,
		Profile.play_secs, Profile.debug_tainted]

	_wipe()
	GameState.hay_dug = 1234.0
	GameState.money_earned = 560.0
	GameState.needles_found = 3
	GameState.money = 500.0
	GameState.money_peak = 789.0
	GameState.run_secs = 200.0
	GameState.run_timed = true
	GameState.first_needle_secs = 100.0
	GameState.debug_used = false
	_write_a_run("career")


	Profile.hay_dug = 999999.0
	Profile.money_earned = 999999.0
	Profile.needles_found = 999
	Profile.money_peak = 999999.0
	Profile.structures_built = 50
	Profile.first_needle_secs = 5.0
	Profile.play_secs = 4321
	Profile.debug_tainted = false
	Profile.call("_rebuild_career")

	_check(is_equal_approx(Profile.hay_dug, 1234.0)
		and is_equal_approx(Profile.money_earned, 560.0)
		and Profile.needles_found == 3,
		"hay, money earned and needles come back as the save has them, not %.0f, $%.0f, %d"
		% [Profile.hay_dug, Profile.money_earned, Profile.needles_found])
	_check(is_equal_approx(Profile.money_peak, 789.0),
		"the richest yard is the run's own record, not $%.0f" % Profile.money_peak)
	_check(is_equal_approx(Profile.first_needle_secs, 100.0),
		"the fastest first needle is the timed run's, not %.1f" % Profile.first_needle_secs)
	_check(Profile.structures_built == 0,
		"a yard with nothing standing counts no structures, not %d" % Profile.structures_built)
	_check(Profile.play_secs == 4321, "time played is kept, not %d" % Profile.play_secs)
	_check(not Profile.debug_tainted, "a run nobody used the debug menu in leaves the boards on")

	_check(SaveManager.structures_in([
			{ "type": "conveyor", "line": 7 }, { "type": "conveyor", "line": 7 },
			{ "type": "conveyor" }, { "type": "platform" }, "not a building"]) == 3,
		"a belt line laid in two pieces counts once, beside a lone belt and a platform")

	GameState.debug_used = true
	_write_a_run("career")
	Profile.call("_rebuild_career")
	_check(Profile.debug_tainted,
		"a save the debug menu was used in takes the game off the boards")

	GameState.hay_dug = kept_state [0]
	GameState.money_earned = kept_state [1]
	GameState.needles_found = kept_state [2]
	GameState.money = kept_state [3]
	GameState.money_peak = kept_state [4]
	GameState.run_secs = kept_state [5]
	GameState.run_timed = kept_state [6]
	GameState.first_needle_secs = kept_state [7]
	GameState.debug_used = kept_state [8]
	Profile.hay_dug = kept_career [0]
	Profile.money_earned = kept_career [1]
	Profile.needles_found = kept_career [2]
	Profile.money_peak = kept_career [3]
	Profile.structures_built = kept_career [4]
	Profile.first_needle_secs = kept_career [5]
	Profile.play_secs = kept_career [6]
	Profile.debug_tainted = kept_career [7]
	_wipe()
