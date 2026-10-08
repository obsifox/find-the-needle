class_name DevCrashProbe
extends Node


const PROBE_SENTINEL:= "user://dev_session.lock"

const PROBE_LOG_DIR:= "user://dev_logs"

const PROBE_OVERRIDE:= "user://dev_override.cfg"

var layer: CanvasLayer

var _fails:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:
	print("--- crash report probe ---")


	await get_tree().process_frame
	await get_tree().process_frame
	_check_the_menu_delivers()


	print("[crash] this run had armed the real sentinel: %s"
		% CrashReport.stand_down())
	CrashReport.sentinel_path = PROBE_SENTINEL
	print("[crash] sentinel redirected to %s" % PROBE_SENTINEL)
	var real_before:= FileAccess.file_exists(CrashReport.SENTINEL)

	_check_clean_run()
	_check_disappearance()
	_check_live_instance()
	_check_crash_handler()
	_check_last_step()
	_check_last_action()
	_check_machine_recorded()
	_check_gpu_driver()
	_check_renderer_choice()
	_check_render_thread_fallback()
	_check_scrubbed()
	_check_quoting()
	_check_flood_folds()
	_check_log_attached()
	await _check_d3d12_offer()
	await _check_intel_fault()
	await _check_windows_events()
	await _check_card()
	_check_submit_without_a_server()
	_check_real_sentinel(real_before)

	_cleanup()
	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _check_the_menu_delivers() -> void:
	var waiting:= CrashReport.pending != ""
	var card:= _find_card()
	print("[crash] a report was waiting at boot: %s" % waiting)
	print("[crash] the menu had already put the card up: %s" % (card != null))


	print("[crash] the automatic send: sent=%s sending=%s error=%s"
		% [CrashReport.sent, CrashReport.sending,
			"none" if CrashReport.last_error == "" else CrashReport.last_error])


	if waiting and Leaderboard.enabled:
		_ok(CrashReport.sending or CrashReport.sent or CrashReport.last_error != "",
			"and the send went off on its own, with nobody asked")
	_ok((card != null) == waiting,
		"the menu raises the card exactly when a report is waiting, unprompted")


	if card != null:
		card.free()


func _find_card() -> CrashReportDialog:
	if layer == null:
		return null
	for child in layer.get_children():
		if child is CrashReportDialog:
			return child
	return null


func _check_clean_run() -> void:
	_wipe()
	CrashReport.pending = ""
	CrashReport.recover()
	_ok(CrashReport.pending == "", "a launch with no sentinel has nothing to report")


func _check_disappearance() -> void:
	_wipe()
	CrashReport.arm()
	_ok(FileAccess.file_exists(PROBE_SENTINEL), "arming writes the sentinel")

	CrashReport.release()
	CrashReport.pending = ""
	CrashReport.recover()
	_ok(CrashReport.pending != "", "a sentinel left behind produces a report")
	_ok(not FileAccess.file_exists(PROBE_SENTINEL),
		"recovering removes the sentinel, so the crash is reported once")
	_ok("stopped without shutting down" in CrashReport.pending_reason,
		"no crash handler means the report says so rather than guessing")


func _check_live_instance() -> void:


	var other:= OS.create_process("cmd.exe", ["/c", "ping -n 30 127.0.0.1 > nul"])
	if other <= 0 or not OS.is_process_running(other):
		print("  skip could not start a process to stand in for a second copy")
		return

	_wipe()
	CrashReport.arm()
	CrashReport.release()


	var f:= FileAccess.open(PROBE_SENTINEL, FileAccess.WRITE)
	f.store_line(JSON.stringify({ "started": Time.get_unix_time_from_system(),
		"pid": other, "build": "probe", "gpu": "probe" }))
	f.close()

	CrashReport.pending = ""
	CrashReport.recover()
	_ok(CrashReport.pending == "",
		"a sentinel owned by a running copy of the game is not a crash")
	_ok(FileAccess.file_exists(PROBE_SENTINEL),
		"and is left where it is, so that copy can still report its own")

	OS.kill(other)


	CrashReport.recover()
	_ok(CrashReport.pending != "",
		"once that copy is gone, the same sentinel is recovered")
	_wipe()


func _check_crash_handler() -> void:
	_wipe()
	CrashReport.arm()


	CrashReport.notification(NOTIFICATION_CRASH)
	CrashReport.release()
	CrashReport.recover()
	_ok("hit a fault" in CrashReport.pending_reason,
		"a stamped sentinel is reported as a fault the engine caught")
	_ok(CrashReport.pending_reason != "The game stopped without shutting down.",
		"the two ways a run can vanish do not read alike")


func _check_last_action() -> void:
	_wipe()
	CrashReport.arm()
	CrashReport.note_stage("loading screen closed", 1.0, false)
	CrashReport.note_doing("build click, hay_compressor")
	CrashReport.note_doing("dismantling conveyor")
	CrashReport.release()
	CrashReport.recover()
	_ok(CrashReport.pending.contains("dismantling conveyor"),
		"the report names what the player was doing when the run ended")
	_ok(not CrashReport.pending.contains("hay_compressor"),
		"and the last one only, not every one of them")


	_ok(CrashReport.pending.contains("before the end"),
		"with how long before the end it happened")


	_wipe()
	CrashReport.arm()
	CrashReport.note_doing("dismantling conveyor")
	CrashReport.note_doing("dismantling conveyor")
	CrashReport.note_doing("dismantling hay_silo")
	CrashReport.release()
	CrashReport.recover()
	_ok(CrashReport.pending.contains("dismantling hay_silo"),
		"a repeated breadcrumb is dropped and the next new one is not")


func _check_last_step() -> void:
	_wipe()
	CrashReport.arm()
	CrashReport.note_stage("SETTLING THE PILE", 0.7)
	CrashReport.release()
	CrashReport.recover()
	_ok(CrashReport.pending.contains("SETTLING THE PILE (70%)"),
		"the report names the loading step the run died on")
	_ok(CrashReport.pending_summary == "stopped on the loading screen at 70%",
		"and a quiet stop groups on that step's percentage")

	_wipe()
	CrashReport.arm()
	CrashReport.note_stage("SETTLING THE PILE", 0.7)
	CrashReport.note_stage("loading screen closed", 1.0, false)
	CrashReport.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	CrashReport.release()
	CrashReport.recover()
	_ok(CrashReport.pending_summary == "stopped while quitting",
		"a run killed after the window was asked to close says so instead")
	_ok(not CrashReport.pending.contains("last error"),
		"and a grouping line is never printed as if it were an error")
	_wipe()


func _check_machine_recorded() -> void:
	_wipe()
	CrashReport.arm()
	CrashReport.release()
	CrashReport.recover()
	var report:= CrashReport.pending
	for field: String in ["build", "engine", "platform", "cpu", "gpu", "gpu driver",
			"vulkan", "renderer"]:
		_ok(report.contains(field), "the report names the %s" % field)
	_ok(report.begins_with("FIND THE NEEDLE crash report"),
		"the report says what it is on its first line")


	print("")
	for line in report.split("\n"):
		if line.begins_with("==== log"):
			break
		print("  | %s" % line)


func _check_gpu_driver() -> void:
	_ok(CrashReport.driver_label("NVIDIA", "32.0.15.6614")
		== "NVIDIA 566.14 (32.0.15.6614)",
		"an NVIDIA driver is shown in NVIDIA's own numbering")
	_ok(CrashReport.driver_label("NVIDIA", "32.0.16.1088")
		== "NVIDIA 610.88 (32.0.16.1088)",
		"...including one past the 16 in the third field")
	_ok(CrashReport.driver_label("Advanced Micro Devices, Inc.", "31.0.24033.1003")
		== "Advanced Micro Devices, Inc. 31.0.24033.1003",
		"an AMD driver is left as Windows gives it")


	_wipe()
	var f:= FileAccess.open(PROBE_SENTINEL, FileAccess.WRITE)
	f.store_line(JSON.stringify({ "started": Time.get_unix_time_from_system() - 60.0,
		"build": "probe", "gpu": "probe", "driver": "1.4.341", "backend": "vulkan" }))
	f.close()
	CrashReport.pending = ""
	CrashReport.recover()
	var old:= CrashReport.pending
	_ok(old.contains("vulkan        1.4.341"),
		"an old sentinel's API version lands on the vulkan row")
	_ok(old.contains("gpu driver    not recorded by this build"),
		"and the driver row says the old build never recorded it")


	_wipe()
	CrashReport.arm()
	CrashReport.release()
	var fresh:= CrashReport.call("_read_sentinel") as Dictionary
	_ok(fresh.has("gpu_driver") and fresh.has("api") and not fresh.has("driver"),
		"this build records gpu_driver and api, and no ambiguous driver key")
	CrashReport.recover()
	_wipe()


func _check_renderer_choice() -> void:
	var was_renderer:= Cfg.renderer
	var was_readonly:= Cfg.settings_readonly
	var was_override:= Cfg.override_file
	Cfg.settings_readonly = true
	Cfg.override_file = PROBE_OVERRIDE

	var seed:= ConfigFile.new()
	seed.set_value("rendering", Cfg.THREAD_MODEL_KEY, Cfg.THREAD_MODEL_SINGLE)
	seed.save(PROBE_OVERRIDE)

	for renderer: String in Cfg.RENDERERS:
		_ok(Cfg.set_renderer(renderer), "%s writes the renderer override" % renderer)
		var cf:= ConfigFile.new()
		cf.load(PROBE_OVERRIDE)
		_ok(str(cf.get_value("rendering", Cfg.RENDERER_DRIVER_KEY, "")) == renderer,
			"...and asks for exactly %s" % renderer)
		for key: String in Cfg.RENDERER_FALLBACK_KEYS:
			_ok(not bool(cf.get_value("rendering", key, true)),
				"...and disables %s" % key)
		_ok(int(cf.get_value("rendering", Cfg.THREAD_MODEL_KEY, 0))
				== Cfg.THREAD_MODEL_SINGLE,
			"...and preserves the render thread override")

	Cfg.renderer = was_renderer
	Cfg.settings_readonly = was_readonly
	Cfg.override_file = was_override


func _check_render_thread_fallback() -> void:
	var was_thread:= Cfg.render_thread
	var was_fell:= Cfg.render_thread_suspect
	var was_readonly:= Cfg.settings_readonly
	var was_override:= Cfg.override_file
	Cfg.settings_readonly = true
	Cfg.override_file = PROBE_OVERRIDE
	var key:= Cfg.THREAD_MODEL_KEY_EXPORT if OS.has_feature("template") else Cfg.THREAD_MODEL_KEY

	Cfg.render_thread = Cfg.RenderThread.ON
	Cfg.render_thread_suspect = false
	_ok(Cfg.sync_render_thread(), "ON writes the override")
	var cf:= ConfigFile.new()
	cf.load(PROBE_OVERRIDE)
	_ok(int(cf.get_value("rendering", key, 0)) == Cfg.THREAD_MODEL_SEPARATE,
		"ON asks the next launch for the separate thread model")


	_wipe()
	CrashReport.arm()
	CrashReport._note({ "render_thread": true, "render_thread_chosen": "ON" })
	CrashReport.release()
	CrashReport.recover()
	_ok(Cfg.render_thread == Cfg.RenderThread.ON,
		"a crash with the render thread on leaves the setting alone")
	_ok(Cfg.render_thread_suspect, "...and has the dialogue ask the player")
	cf = ConfigFile.new()
	cf.load(PROBE_OVERRIDE)
	_ok(int(cf.get_value("rendering", key, 0)) == Cfg.THREAD_MODEL_SEPARATE,
		"...and the override still asks for the separate thread")
	_ok(CrashReport.pending.contains("on (settings asked for ON)"),
		"the report says the render thread was on")


	Cfg.render_thread = Cfg.RenderThread.OFF
	Cfg.render_thread_suspect = false
	_wipe()
	CrashReport.arm()
	CrashReport._note({ "render_thread": true, "render_thread_chosen": "ON" })
	CrashReport.release()
	CrashReport.recover()
	_ok(not Cfg.render_thread_suspect,
		"a crash with the thread on is not asked about once it is OFF")


	Cfg.render_thread = Cfg.RenderThread.ON
	Cfg.render_thread_suspect = false
	_wipe()
	CrashReport.arm()
	CrashReport._note({ "render_thread": false, "render_thread_chosen": "ON" })
	CrashReport.release()
	CrashReport.recover()
	_ok(Cfg.render_thread == Cfg.RenderThread.ON and not Cfg.render_thread_suspect,
		"a crash with the render thread off leaves the setting alone and asks nothing")
	_ok(CrashReport.pending.contains("render thread"),
		"...and the report still says which it was")

	Cfg.render_thread = was_thread
	Cfg.render_thread_suspect = was_fell
	Cfg.settings_readonly = was_readonly
	Cfg.override_file = was_override
	if FileAccess.file_exists(PROBE_OVERRIDE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_OVERRIDE))


func _check_scrubbed() -> void:
	var home:= OS.get_environment("USERPROFILE")
	if home.length() < 4:
		home = OS.get_environment("HOME")
	if home.length() < 4:
		print("  skip no home directory in the environment to scrub")
		return
	_wipe()
	CrashReport.arm()
	CrashReport.release()
	CrashReport.recover()
	_ok(not CrashReport.pending.contains(home),
		"the home directory is scrubbed out of the report")
	_ok(not CrashReport.pending.contains(home.replace("\\", "/")),
		"and scrubbed in the slash direction Godot prints")


func _check_quoting() -> void:
	var path:= "user://dev_crash_quote.log"
	var f:= FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_ok(false, "could not write a log to quote")
		return
	var total:= CrashReport.HEAD_LINES + CrashReport.TAIL_LINES + 500
	for i in total:
		f.store_line("line %d" % i)
	f.close()

	var quoted:= str(CrashReport.call("_quote", path))
	_ok(quoted.contains("line 0"), "the head of a long log is quoted")
	_ok(quoted.contains("line %d" % (total - 1)), "and so is the tail")
	_ok(quoted.contains("500 lines left out of the middle"),
		"and the middle is named rather than silently dropped")
	_ok(not quoted.contains("line %d" % (CrashReport.HEAD_LINES + 200)),
		"the middle really is left out")
	DirAccess.remove_absolute(path)


func _check_flood_folds() -> void:
	var path:= "user://dev_crash_flood.log"
	var f:= FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_ok(false, "could not write a flooded log to quote")
		return
	for i in 40:
		f.store_line("banner line %d" % i)
	var floods:= 1500
	for i in floods:
		f.store_line("ERROR: Condition \"!is_inside_tree()\" is true. Returning: Transform3D()")
		f.store_line("   at: Node3D::get_global_transform (scene\\3d\\node_3d.cpp:649)")


	f.store_line("FATAL: the fault that actually mattered")
	f.close()

	var quoted:= str(CrashReport.call("_quote", path))
	_ok(quoted.contains("banner line 0"), "a flooded log still starts at the top")
	_ok(quoted.contains("appear %d times in a row" % floods),
		"the repeating block is folded up and counted")
	_ok(quoted.contains("FATAL: the fault that actually mattered"),
		"and the last thing the process said survived the fold")
	_ok(not quoted.contains("lines left out of the middle"),
		"a log that is mostly one repeated error now arrives whole")


	_ok(quoted.length() < CrashReport.MAX_REPORT,
		"and it fits inside what gets uploaded")


	_ok(str(CrashReport.call("_summarise", quoted)).contains("actually mattered"),
		"the summary names the fault and not the flood")
	DirAccess.remove_absolute(path)


func _check_log_attached() -> void:
	var real_path:= str(ProjectSettings.get_setting("debug/file_logging/log_path", ""))
	ProjectSettings.set_setting("debug/file_logging/log_path",
		PROBE_LOG_DIR.path_join("godot.log"))
	DirAccess.make_dir_recursive_absolute(PROBE_LOG_DIR)
	_wipe()
	CrashReport.arm()


	var planted:= PROBE_LOG_DIR.path_join("godot_probe.log")
	var f:= FileAccess.open(planted, FileAccess.WRITE)
	f.store_line("Godot Engine v4.7.1.stable.official - https://godotengine.org")
	f.store_line("ERROR: the pile fell over")
	f.store_line("   at: dig (res://scripts/world/pile.gd:120)")
	f.close()


	var now:= Time.get_unix_time_from_system()
	CrashReport.call("_note", { "started": now - 3600.0, "alive_at": now - 3000.0 })
	CrashReport.release()
	CrashReport.recover()
	_ok(CrashReport.pending.contains("the pile fell over"),
		"the crashed run's log is quoted into the report")
	_ok(CrashReport.pending_summary.contains("the pile fell over"),
		"and the last error is picked out, to group the report by")
	_ok(not CrashReport.pending.contains("No log survived"),
		"so the report does not go out claiming there was no log")
	_ok(CrashReport.saved_log != "",
		"and a copy is kept where log rotation cannot reach it")
	for line in CrashReport.pending.split("\n"):
		if line.begins_with("when") or line.begins_with("ran for"):
			print("  | %s" % line)
	_ok(CrashReport.pending.contains("ran for       10 minutes"),
		"the run lasted until its last stamp, not until the log was copied")
	_ok(CrashReport.pending.contains("last seen alive"),
		"and the report says the end is the last sign of life")


	if CrashReport.saved_log != "":
		DirAccess.remove_absolute(CrashReport.CRASH_DIR.path_join(
			CrashReport.saved_log.get_file()))
	ProjectSettings.set_setting("debug/file_logging/log_path", real_path)
	DirAccess.remove_absolute(planted)
	DirAccess.remove_absolute(PROBE_LOG_DIR)


func _recover_with_log(lines: Array, notes: Dictionary) -> void:
	var real_path:= str(ProjectSettings.get_setting("debug/file_logging/log_path", ""))
	ProjectSettings.set_setting("debug/file_logging/log_path",
		PROBE_LOG_DIR.path_join("godot.log"))
	DirAccess.make_dir_recursive_absolute(PROBE_LOG_DIR)
	_wipe()
	CrashReport.arm()
	var planted:= PROBE_LOG_DIR.path_join("godot_probe.log")
	var f:= FileAccess.open(planted, FileAccess.WRITE)
	for line: String in lines:
		f.store_line(line)
	f.close()
	CrashReport.call("_note", notes)
	CrashReport.release()
	CrashReport.recover()
	if CrashReport.saved_log != "":
		DirAccess.remove_absolute(CrashReport.CRASH_DIR.path_join(
			CrashReport.saved_log.get_file()))
	ProjectSettings.set_setting("debug/file_logging/log_path", real_path)
	DirAccess.remove_absolute(planted)
	DirAccess.remove_absolute(PROBE_LOG_DIR)


func _check_d3d12_offer() -> void:
	var was_renderer:= Cfg.renderer
	var was_thread:= Cfg.render_thread
	var was_suspect:= Cfg.render_thread_suspect
	Cfg.render_thread = Cfg.RenderThread.ON

	var lost:= "ERROR: Vulkan device was lost. This could be due to a driver issue."
	var fence:= "ERROR: Couldn't wait for Vulkan fence (VkResult error -4)"
	_ok(CrashReport.lost_vulkan_device(lost), "the lost present line reads as a lost device")
	_ok(CrashReport.lost_vulkan_device(fence), "and so does a fence wait that got -4")
	_ok(not CrashReport.lost_vulkan_device("ERROR: Can't create buffer (VkResult error -10)")
		and not CrashReport.lost_vulkan_device("(VkResult error -2)"),
		"running out of allocations or memory does not")

	var on_vulkan:= { "backend": "vulkan", "render_thread": true, "render_thread_chosen": "ON" }
	Cfg.renderer = "vulkan"
	_recover_with_log(["Godot Engine v4.7.1", lost], on_vulkan)
	_ok(CrashReport.offer_d3d12, "a lost Vulkan device offers Direct3D 12")
	_ok(not Cfg.render_thread_suspect, "...in place of the render thread box")

	Cfg.renderer = "d3d12"
	_recover_with_log(["Godot Engine v4.7.1", lost], on_vulkan)
	_ok(not CrashReport.offer_d3d12, "not to a player already moved to Direct3D 12")
	_ok(Cfg.render_thread_suspect, "...who is asked about the thread as before")

	Cfg.renderer = "vulkan"
	var on_d3d12:= on_vulkan.duplicate()
	on_d3d12.backend = "d3d12"
	_recover_with_log(["Godot Engine v4.7.1", lost], on_d3d12)
	_ok(not CrashReport.offer_d3d12, "not when the run was drawing on Direct3D 12")

	_recover_with_log(["Godot Engine v4.7.1", "ERROR: the pile fell over"], on_vulkan)
	_ok(not CrashReport.offer_d3d12 and Cfg.render_thread_suspect,
		"and a crash that was not the device keeps the render thread box")
	_ok(not CrashReport.offer_vulkan, "a run on Vulkan is never offered Vulkan")


	_recover_with_log(["Godot Engine v4.7.1"], on_d3d12)
	_ok(CrashReport.offer_vulkan, "a run that ended on Direct3D 12 offers Vulkan")
	_ok(not CrashReport.offer_d3d12 and not Cfg.render_thread_suspect,
		"...and nothing else beside it")
	Cfg.renderer = "d3d12"
	_recover_with_log(["Godot Engine v4.7.1", "ERROR: the pile fell over"], on_d3d12)
	_ok(CrashReport.offer_vulkan, "whether the player picked Direct3D 12 or not")

	OS.set_environment("FTN_FAKE_GPU", "AMD Radeon RX 5600 XT")
	_recover_with_log(["Godot Engine v4.7.1"], on_d3d12)
	OS.unset_environment("FTN_FAKE_GPU")
	_ok(not CrashReport.offer_vulkan, "but never to a card whose Vulkan cannot hold")


	CrashReport.offer_d3d12 = true
	CrashReport.offer_vulkan = false
	Cfg.render_thread_suspect = false
	var card:= CrashReportDialog.new()
	add_child(card)
	await get_tree().process_frame
	_ok(_find_button(card, CrashReportDialog.BTN_D3D12) != null,
		"the card has a button to switch to Direct3D 12")
	_ok(_find_button(card, CrashReportDialog.BTN_THREAD_OFF) == null
		and _find_button(card, CrashReportDialog.BTN_VULKAN) == null,
		"and no other offer beside it")
	card.free()


	CrashReport.offer_d3d12 = false
	CrashReport.offer_vulkan = true
	card = CrashReportDialog.new()
	add_child(card)
	await get_tree().process_frame
	_ok(_find_button(card, CrashReportDialog.BTN_VULKAN) != null
		and _find_button(card, CrashReportDialog.BTN_D3D12) == null,
		"the card offers Vulkan after a Direct3D 12 run")
	card.free()

	CrashReport.offer_d3d12 = false
	CrashReport.offer_vulkan = false
	Cfg.renderer = was_renderer
	Cfg.render_thread = was_thread
	Cfg.render_thread_suspect = was_suspect


func _check_intel_fault() -> void:
	var cases:= {
		"Intel(R) Core(TM) i9-14900K": "i9-14900K",
		"Intel(R) Core(TM) i9-14900KS": "i9-14900KS",
		"Intel(R) Core(TM) i9-13900KF": "i9-13900KF",
		"Intel(R) Core(TM) i9-13900": "i9-13900",
		"Intel(R) Core(TM) i7-14790F": "i7-14790F",
		"Intel(R) Core(TM) i7-13700": "i7-13700",
		"Intel(R) Core(TM) i5-14600KF": "i5-14600KF",
		"13th Gen Intel(R) Core(TM) i5-13600K": "i5-13600K",
		"13th Gen Intel(R) Core(TM) i7-1355U": "",
		"12th Gen Intel(R) Core(TM) i5-1235U": "",
		"13th Gen Intel(R) Core(TM) i9-13980HX": "",
		"13th Gen Intel(R) Core(TM) i7-13700H": "",
		"Intel(R) Core(TM) i9-13900T": "",
		"13th Gen Intel(R) Core(TM) i5-13400F": "",
		"Intel(R) Core(TM) i5-14600": "",
		"Intel(R) Core(TM) i9-12900K": "",
		"AMD Ryzen 7 5700G with Radeon Graphics": "",
	}
	for cpu: String in cases:
		var got:= CrashReport.intel_fault_model(cpu)
		_ok(got == cases [cpu], "%s reads as \"%s\" (got \"%s\")" % [cpu, cases [cpu], got])

	var line:= "ERROR: the pile fell over"
	_recover_with_log(["Godot Engine v4.7.1", line], { "cpu": "Intel(R) Core(TM) i9-14900K" })
	_ok(CrashReport.intel_fault == "i9-14900K", "a crash on an i9-14900K is flagged")
	_ok(CrashReport.pending.begins_with("!! INTEL CPU WITH A KNOWN FAULT: i9-14900K\n"),
		"...on the very first line of the report")
	_ok(CrashReport.pending.find("FIND THE NEEDLE crash report") > 0,
		"...with the usual report under it")
	var card:= CrashReportDialog.new()
	add_child(card)
	await get_tree().process_frame
	_ok(_find_button(card, CrashReportDialog.BTN_INTEL) != null,
		"the card has the Intel box with a button to the Discord channel")
	card.free()

	_recover_with_log(["Godot Engine v4.7.1", line],
		{ "cpu": "13th Gen Intel(R) Core(TM) i7-1355U" })
	_ok(CrashReport.intel_fault == "" and not CrashReport.pending.contains("INTEL CPU"),
		"a laptop i7-1355U is not flagged")
	card = CrashReportDialog.new()
	add_child(card)
	await get_tree().process_frame
	_ok(_find_button(card, CrashReportDialog.BTN_INTEL) == null,
		"...and its card has no Intel box")
	card.free()
	CrashReport.intel_fault = ""


func _check_windows_events() -> void:

	var died:= floorf(Time.get_unix_time_from_system()) - 600.0
	var at:= func(offset: float) -> String:
		return Time.get_datetime_string_from_unix_time(int(died + offset)) + ".1234567Z"
	var sys:= "<System><Provider Name='%s'/><EventID>%d</EventID><TimeCreated SystemTime='%s'/>" + "<Computer>PROBE-PC</Computer><Security UserID='S-1-5-21-111-222'/></System>"

	var crash:= "<Event>" + sys % ["Application Error", 1000, at.call(5.0)] + "<EventData>" + "<Data Name='AppName'>FindTheNeedle.exe</Data>" + "<Data Name='ModuleName'>nvoglv64.dll</Data>" + "<Data Name='ModuleVersion'>32.0.15.6614</Data>" + "<Data Name='ExceptionCode'>c0000005</Data>" + "<Data Name='FaultingOffset'>0000000000abc123</Data>" + "<Data Name='ProcessId'>0x1234</Data>" + "<Data Name='AppPath'>C:\\Users\\probe_player\\Game\\FindTheNeedle.exe</Data>" + "</EventData></Event>"

	var other:= "<Event>" + sys % ["Application Error", 1000, at.call(9.0)] + "<EventData>" + "<Data Name='AppName'>FindTheNeedle.exe</Data>" + "<Data Name='ModuleName'>somebody_else.dll</Data>" + "<Data Name='ProcessId'>0x9999</Data></EventData></Event>"
	var hang:= "<Event>" + sys % ["Application Hang", 1002, at.call(240.0)] + "<EventData>" + "<Data Name='AppName'>FindTheNeedle.exe</Data>" + "<Data Name='ProcessId'>0x1234</Data><Data Name='HangType'>Unknown</Data>" + "<Data Name='ExeFileName'>C:\\Users\\probe_player\\Game\\FindTheNeedle.exe</Data>" + "</EventData></Event>"

	var app_xml:= hang + other + crash
	var gpu_xml:= "<Event>" + sys % ["Display", 4101, at.call(3.0)] + "<EventData><Data>nvlddmkm</Data><Data></Data></EventData></Event>"
	gpu_xml += "<Event>" + sys % ["nvlddmkm", 153, at.call(2.0)] + "<EventData><Data>\\Device\\Video3</Data><Data>Error occurred on GPUID: 100</Data>" + "<Binary>DEADBEEF</Binary></EventData></Event>"

	var rows:= CrashReport.windows_event_rows(app_xml, gpu_xml, died, 4660)
	var lines:= PackedStringArray()
	for row: Array in rows:
		lines.append("%-13s %s" % [row [0], row [1]])
		print("  | %s" % lines [-1])
	var all:= "\n".join(lines)
	_ok(all.contains("crashed in nvoglv64.dll 32.0.15.6614, code 0xc0000005 at offset 0xabc123 (5 s after it was last seen)"),
		"a crash names the DLL, its version, the code and the offset, against the last sign of life")
	_ok(not all.contains("somebody_else"), "a crash under another process id is left out")
	_ok(all.contains("stopped responding and was closed (4 minutes after it was last seen)"),
		"a freeze reads as one")
	_ok(all.contains("nvlddmkm 153: Error occurred on GPUID: 100 (2 s after it was last seen)"),
		"a driver event keeps its words")
	_ok(all.contains("Display 4101, the driver stopped responding and was recovered: nvlddmkm"),
		"a recovered display driver is said in words")
	_ok(lines.size() == 4 and lines [0].begins_with("windows") and lines [3].begins_with("gpu event")
		and lines [2].contains("nvlddmkm 153"),
		"the game's own rows come first, then the driver's, each oldest first")
	for secret: String in ["probe_player", "PROBE-PC", "S-1-5-21", "\\Device", "DEADBEEF"]:
		_ok(not all.contains(secret), "nothing that names the machine leaves it: no '%s'" % secret)

	_ok(CrashReport.windows_app_query("FindTheNeedle.exe", died)
		.contains("[Data[@Name='AppName']='FindTheNeedle.exe']"),
		"the app query asks for this game by name")
	_ok(not CrashReport.windows_app_query("Find'The.exe", died).contains("AppName"),
		"and leaves a name with an apostrophe to the process id")


	var heard:= [0]
	var count:= func() -> void: heard [0] += 1
	CrashReport.pending_changed.connect(count)
	_recover_with_log(["Godot Engine v4.7.1"], { "backend": "vulkan" })
	CrashReport.windows_rows = rows
	CrashReport.call("_recompose")
	CrashReport.pending_changed.disconnect(count)
	_ok(CrashReport.pending.contains("gpu event     nvlddmkm 153"),
		"the rows go into the report's header")
	_ok(heard [0] == 1, "and the card is told the report changed")
	CrashReport.windows_rows = []


	if OS.get_name() != "Windows":
		print("  skip wevtutil is Windows only")
		return
	var now:= Time.get_unix_time_from_system()
	var t0:= Time.get_ticks_msec()
	var live: Array = CrashReport.call("_windows_events_job", now - 86400.0, now - 60.0,
		OS.get_process_id(), OS.get_executable_path().get_file(), now)
	var took:= Time.get_ticks_msec() - t0
	for row: Array in live:
		print("  | live %-13s %s" % [row [0], row [1]])
	_ok(not live.is_empty(), "the live read always says something")
	var unread:= false
	for row: Array in live:
		unread = unread or str(row [1]).begins_with("could not be read")
	_ok(not unread, "both live queries were accepted by this machine's wevtutil")
	print("  live read took %d ms" % took)
	_ok(took < CrashReport.WINDOWS_WAIT_MS, "inside the time the send waits for it")


	_recover_with_log(["Godot Engine v4.7.1"], { "backend": "vulkan" })
	CrashReport.call("_start_windows_events")
	_ok(CrashReport.pending.contains("still being read"),
		"the card first says Windows is still being asked")

	CrashReport.call("_await_windows_events")
	_ok(CrashReport.busy(), "and the send is held while it is")
	var give_up:= Time.get_ticks_msec() + CrashReport.WINDOWS_WAIT_MS + 2000
	while CrashReport.busy() and Time.get_ticks_msec() < give_up:
		await get_tree().process_frame
	_ok(not CrashReport.busy(), "the hold is let go once Windows has answered")
	var answered:= CrashReport.pending.contains("\nwindows ") or CrashReport.pending.contains("\ngpu event ")
	_ok(answered and not CrashReport.pending.contains("still being read"),
		"and the report carries the answer")
	_ok(CrashReport.get("_events_thread") == null, "and the thread is joined")
	CrashReport.windows_rows = []


func _check_card() -> void:
	CrashReport.fake_pending("FIND THE NEEDLE crash report\nmade up, by the probe\n")


	var was_suspect:= Cfg.render_thread_suspect
	Cfg.render_thread_suspect = true
	var card:= CrashReportDialog.new()
	if layer != null:
		layer.add_child(card)
	else:
		add_child(card)
	await get_tree().process_frame

	var box:= _find_box(card)
	_ok(box != null, "the card builds and has a box to read the report out of")
	if box != null:
		_ok(box.text == CrashReport.pending, "the box holds the whole report")
		_ok(not box.editable, "the report cannot be edited before it is sent")

	var copy:= _find_button(card, CrashReportDialog.BTN_COPY)
	_ok(copy != null, "the card has a copy button")
	if copy != null and DisplayServer.get_name() != "headless":
		copy.pressed.emit()


		var back:= DisplayServer.clipboard_get().replace("\r\n", "\n")
		if back != CrashReport.pending:
			print("  dbg wrote %d chars, read %d back"
				% [CrashReport.pending.length(), back.length()])
		_ok(back == CrashReport.pending,
			"copying puts the report on the clipboard unchanged")
	elif copy != null:
		print("  skip no clipboard on a headless display server")

	var send:= _find_button(card, CrashReportDialog.BTN_SEND)
	_ok(send != null, "and a send button, for the case where the report is stuck")
	_ok(send != null and not send.visible,
		"which stays out of sight while there is nothing for the player to do")
	_ok(_find_button(card, CrashReportDialog.BTN_CLOSE) != null, "and a way out")


	_ok(_find_button(card, CrashReportDialog.BTN_THREAD_OFF) == null,
		"after a crash with the render thread on, no button that turns it off")
	Cfg.render_thread_suspect = was_suspect


	var status:= _status_of(card)


	_ok(status != "", "the card has a status line to read")
	for word: String in ["sent", "Sending", "thank"]:
		_ok(not status.containsn(word),
			"the card does not mention the send: no '%s'" % word)


	CrashReport.sending = false
	CrashReport.sent = false
	CrashReport.last_error = "no internet connection"
	CrashReport.send_finished.emit(false, CrashReport.last_error)
	_ok(send != null and send.visible == Leaderboard.enabled,
		"a failed send puts the button up, wherever there is a server to reach")


	CrashReport.last_error = ""
	CrashReport.send_finished.emit(false, "")
	await _photograph()
	card.free()


func _photograph() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var shot:= get_viewport().get_texture().get_image()
	var out:= "res://captures/crash_report.png"
	if shot.save_png(out) == OK:
		print("  shot %s" % out)


func _check_submit_without_a_server() -> void:
	var heard: Array = []
	CrashReport.send_finished.connect(func(ok: bool, why: String) -> void:
		heard.append([ok, why]))

	var res: Dictionary = await CrashReport.submit()
	_ok(not res.ok, "submitting with no server available fails rather than hangs")
	_ok(str(res.error) != "", "and says why, in words the card can show")
	_ok(heard.size() == 1, "and tells the card it is over, exactly once")
	_ok(heard.size() == 1 and not heard [0] [0],
		"with the answer it actually got")
	_ok(CrashReport.last_error != "",
		"and keeps the reason, for a card built after the fact")
	_ok(not CrashReport.sending, "and is not left looking like it is still going")


func _check_real_sentinel(existed_before: bool) -> void:
	_ok(FileAccess.file_exists(CrashReport.SENTINEL) == existed_before,
		"the player's own sentinel was neither written nor removed")


func _wipe() -> void:
	CrashReport.release()
	if FileAccess.file_exists(PROBE_SENTINEL):
		DirAccess.remove_absolute(PROBE_SENTINEL)


func _cleanup() -> void:
	_wipe()
	CrashReport.pending = ""


func _status_of(node: Node) -> String:
	var status:= node.find_child("Status", true, false) as Label
	return "" if status == null else status.text


func _find_box(node: Node) -> TextEdit:
	if node is TextEdit:
		return node
	for child in node.get_children():
		var found:= _find_box(child)
		if found != null:
			return found
	return null


func _find_button(node: Node, node_name: String) -> Button:
	var found:= node.find_child(node_name, true, false)
	return found as Button
