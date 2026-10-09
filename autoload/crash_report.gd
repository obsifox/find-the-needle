extends Node


const SENTINEL:= "user://session.lock"


const CRASH_DIR:= "user://crashes"


const REASON_CRASHED:= "The game hit a fault and was closed by the system."

const REASON_QUIET:= "The game stopped without shutting down."


const KEEP_CRASHES:= 10


const DOING_REPEAT:= 1.0


const HEARTBEAT:= 30.0


const WINDOWS_WAIT_MS:= 8000


const WINDOWS_APP_EVENTS:= 3
const WINDOWS_GPU_EVENTS:= 5


const WINDOWS_GPU_AFTER:= 300.0


const WINDOWS_GPU_SOURCES:= ["nvlddmkm", "amdkmdag", "amdkmdap", "igfx", "igfxn"]


const HEAD_LINES:= 60
const TAIL_LINES:= 400


const MAX_PERIOD:= 12
const MIN_RUNS:= 3


const MAX_REPORT:= 64 * 1024


signal send_started()
signal send_finished(ok: bool, error: String)


signal pending_changed()


var enabled:= true


var pending:= ""

var pending_reason:= ""


var pending_summary:= ""


var saved_log:= ""

var sent:= false


var last_error:= ""


var sending:= false


var sentinel_path:= SENTINEL


var _lock: FileAccess = null

var _crash_line:= ""


var _doing:= ""
var _doing_at:= 0.0

var _heartbeat: Timer = null


var offer_d3d12:= false


var offer_vulkan:= false


## true when the previous run died on the loading screen. The world then
## builds in safe mode: every risky sub-step gets its own rendered frame
## behind its own breadcrumb, and decorative FX stay out of the load path
## until they are first used.
var safe_load:= false


## The last note_doing() of the run that died -- "standbuild:skin" and
## friends. Lets code branch on WHERE the last run stopped, not just that
## it stopped.
var last_doing:= ""


var intel_fault:= ""


var windows_rows: Array = []


var _recovered:= { }

var _events_thread: Thread = null

var _reading_windows:= false


func busy() -> bool:
        return sending or _reading_windows


func _ready() -> void:
        if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
                enabled = false
                return


        recover()
        arm()


        if pending != "":
                _start_windows_events()
                _auto_send()


func _exit_tree() -> void:
        _disarm()


        if _events_thread != null:
                _events_thread.wait_to_finish()
                _events_thread = null


func _notification(what: int) -> void:
        if what == NOTIFICATION_CRASH:
                _stamp_crash()
        elif what == NOTIFICATION_WM_CLOSE_REQUEST:


                if not get_tree().auto_accept_quit:
                        return


                _note({ "quitting": Time.get_unix_time_from_system() })


func arm() -> void:
        var session:= {
                "started": Time.get_unix_time_from_system(),


                "pid": OS.get_process_id(),


                "exe": OS.get_executable_path().get_file(),
                "build": _build_string(),
                "engine": str(Engine.get_version_info().get("string", "")),
                "platform": OS.get_name(),
                "os_version": OS.get_version(),
                "cpu": OS.get_processor_name(),
                "threads": OS.get_processor_count(),
                "memory_gb": _physical_memory_gb(),
                "gpu": RenderingServer.get_video_adapter_name(),
                "vendor": RenderingServer.get_video_adapter_vendor(),


                "gpu_driver": _gpu_driver(),
                "api": RenderingServer.get_video_adapter_api_version(),
                # MOBILE FIX (v2.3.0): report the renderer the engine is
                # ACTUALLY running. The old line read the base project
                # setting and printed "forward_plus" on phones that were in
                # fact on the .mobile override -- which cost a whole release
                # of misdiagnosis (v2.2.0's report said forward_plus while
                # the phone was on the mobile renderer).
                "renderer": RenderingServer.get_current_rendering_method(),
                "renderer_project": str(ProjectSettings.get_setting(
                        "rendering/renderer/rendering_method", "")),


                "backend": RenderingServer.get_current_rendering_driver_name(),
                "backend_chosen": Cfg.renderer,


                "render_thread": Cfg.running_render_thread(),
                "render_thread_chosen": Cfg.RENDER_THREAD_NAMES [Cfg.render_thread],
        }
        _lock = FileAccess.open(sentinel_path, FileAccess.WRITE)
        if _lock == null:
                return
        _lock.store_line(JSON.stringify(session))
        _lock.flush()


        _crash_line = JSON.stringify({ "crashed": true })
        if _heartbeat == null:
                _heartbeat = Timer.new()
                _heartbeat.name = "Heartbeat"
                _heartbeat.wait_time = HEARTBEAT


                _heartbeat.process_mode = Node.PROCESS_MODE_ALWAYS
                _heartbeat.timeout.connect(_beat)
                add_child(_heartbeat)
        _heartbeat.start()


func _beat() -> void:
        _note({ "alive_at": Time.get_unix_time_from_system() })


func note_stage(caption: String, progress: float, loading: bool = true) -> void:
        _note({ "stage": caption, "progress": snappedf(progress, 0.01),
                "loading": loading, "pile": str(Cfg.pile_size_id),
                "stage_at": Time.get_unix_time_from_system() })
        # LOG FIX (v2.4.0): the loading trail must survive a hard driver crash
        # and land in a folder the player can open. The sentinel only helps on
        # the next clean launch; GameLog writes the same trail to shared storage.
        GameLog.put("stage", "%s (%d%%)" % [caption, int(round(progress * 100.0))])


func note_doing(what: String) -> void:
        if what == "":
                return
        var now:= Time.get_unix_time_from_system()


        if what == _doing and now - _doing_at < DOING_REPEAT:
                return
        _doing = what
        _doing_at = now
        _note({ "doing": what, "doing_at": now })
        GameLog.put("doing", what)


func _note(fields: Dictionary) -> void:
        if _lock == null:
                return
        _lock.store_line(JSON.stringify(fields))
        _lock.flush()


func _stamp_crash() -> void:
        if _lock == null:
                return
        _lock.store_line(_crash_line)
        _lock.flush()


func _disarm() -> void:
        if _heartbeat != null:
                _heartbeat.stop()
        if _lock != null:
                _lock.close()
                _lock = null
        if FileAccess.file_exists(sentinel_path):
                DirAccess.remove_absolute(sentinel_path)


func stand_down() -> bool:
        if _lock == null:
                return false
        _disarm()
        return true


func release() -> void:
        if _heartbeat != null:
                _heartbeat.stop()
        if _lock != null:
                _lock.close()
                _lock = null


func _read_sentinel() -> Dictionary:
        var f:= FileAccess.open(sentinel_path, FileAccess.READ)
        if f == null:
                return { }
        var out:= { }
        while not f.eof_reached():
                var line:= f.get_line().strip_edges()
                if line == "":
                        continue
                var parsed: Variant = JSON.parse_string(line)
                if parsed is Dictionary:
                        out.merge(parsed, true)
        f.close()
        return out


func recover() -> void:
        offer_d3d12 = false
        offer_vulkan = false
        intel_fault = ""
        windows_rows = []
        _recovered = { }
        if not FileAccess.file_exists(sentinel_path):
                return
        var session:= _read_sentinel()


        var owner: int = int(session.get("pid", 0))
        if owner > 0 and owner != OS.get_process_id() and OS.is_process_running(owner):
                return


        DirAccess.remove_absolute(sentinel_path)

        var crashed:= bool(session.get("crashed", false))
        pending_reason = REASON_CRASHED if crashed else REASON_QUIET

        var started:= float(session.get("started", 0.0))
        var previous:= _previous_log(started)
        var text:= ""
        if previous != "":
                saved_log = _keep(previous)
                text = _quote(previous)


        var died_at:= 0.0
        for key: String in ["alive_at", "stage_at", "doing_at", "quitting"]:
                died_at = maxf(died_at, float(session.get(key, 0.0)))


        pending_summary = _scrub(_summarise(text))

        intel_fault = intel_fault_model(str(session.get("cpu", "")))
        _recovered = { "session": session, "crashed": crashed, "started": started,
                "died_at": died_at, "text": text, "error": pending_summary }
        pending = _compose(session, crashed, started, died_at, text, pending_summary)

        # LOG FIX (v2.4.0): persist the composed report as a FILE the player
        # can find and send, even if the in-game dialog is never opened.
        GameLog.put("crash", "previous run died: %s" % pending_reason)
        GameLog.write_artifact("crash_report_%s.txt" % _artifact_stamp(), pending)


        last_doing = str(session.get("doing", ""))
        safe_load = bool(session.get("loading", false))


        if pending_summary == "" and not crashed:
                pending_summary = _quiet_summary(session)


        offer_d3d12 = OS.get_name() == "Windows" and str(session.get("backend", "")) == "vulkan" and Cfg.renderer != "d3d12" and lost_vulkan_device(text)


        offer_vulkan = OS.get_name() == "Windows" and str(session.get("backend", "")) == "d3d12" and not Cfg.vulkan_lost_gpu()


        Cfg.render_thread_suspect = bool(session.get("render_thread", false)) and Cfg.render_thread != Cfg.RenderThread.OFF and not offer_d3d12 and not offer_vulkan


static func intel_fault_model(cpu: String) -> String:
        var re:= RegEx.create_from_string(
                "(?i)\\b(i[579])-(1[34](?:900(?:ks|kf|k|f)?|700(?:kf|k|f)?|790f|600kf?))\\b")
        var m:= re.search(cpu)
        if m == null:
                return ""
        return "%s-%s" % [m.get_string(1).to_lower(), m.get_string(2).to_upper()]


static func lost_vulkan_device(text: String) -> bool:
        return "Vulkan device was lost" in text or "VK_ERROR_DEVICE_LOST" in text or "VkResult error -4)" in text


static func _artifact_stamp() -> String:
        return Time.get_datetime_string_from_system(true, true).replace(" ", "_").replace(":", ".")


func _previous_log(started: float) -> String:
        var configured:= str(ProjectSettings.get_setting(
                "debug/file_logging/log_path", "user://logs/godot.log"))
        var folder:= configured.get_base_dir()
        var live:= configured.get_file()
        var stem:= live.get_basename()
        var dir:= DirAccess.open(folder)
        if dir == null:
                return ""

        var best:= ""
        var best_time:= 0
        for name in dir.get_files():
                if name == live or not name.begins_with(stem):
                        continue
                var path:= folder.path_join(name)
                var stamp:= FileAccess.get_modified_time(path)
                if stamp > best_time:
                        best_time = stamp
                        best = path


        if best != "" and started > 0.0 and float(best_time) < started - 5.0:
                return ""
        return best


func _keep(path: String) -> String:
        DirAccess.make_dir_recursive_absolute(CRASH_DIR)
        var stamp:= Time.get_datetime_string_from_system(false, false).replace(":", ".")
        var dest:= CRASH_DIR.path_join("crash_%s.log" % stamp)
        if DirAccess.copy_absolute(path, dest) != OK:
                return ""
        GameLog.mirror_file(dest, "engine_log_%s.log" % _artifact_stamp())
        _prune()
        return ProjectSettings.globalize_path(dest)


func _prune() -> void:
        var dir:= DirAccess.open(CRASH_DIR)
        if dir == null:
                return
        var files:= Array(dir.get_files())
        files.sort()
        while files.size() > KEEP_CRASHES:
                DirAccess.remove_absolute(CRASH_DIR.path_join(str(files.pop_front())))


func _quote(path: String) -> String:
        var f:= FileAccess.open(path, FileAccess.READ)
        if f == null:
                return ""


        var lines:= _collapse(f.get_as_text().split("\n", false))
        f.close()
        var n:= lines.size()
        if n <= HEAD_LINES + TAIL_LINES:
                return "\n".join(lines)

        var out:= PackedStringArray()
        for i in HEAD_LINES:
                out.append(lines [i])
        out.append("")
        out.append("... %d lines left out of the middle ..." % (n - HEAD_LINES - TAIL_LINES))
        out.append("")
        for i in range(n - TAIL_LINES, n):
                out.append(lines [i])
        return "\n".join(out)


func _collapse(lines: PackedStringArray) -> PackedStringArray:
        var out:= PackedStringArray()
        var n:= lines.size()
        var i:= 0
        while i < n:
                var period:= 0
                var runs:= 0
                for p in range(1, MAX_PERIOD + 1):


                        if i + p * MIN_RUNS > n:
                                break
                        var r:= 1
                        while _block_matches(lines, i, i + r * p, p):
                                r += 1
                        if r >= MIN_RUNS:
                                period = p
                                runs = r
                                break
                if period == 0:
                        out.append(lines [i])
                        i += 1
                        continue
                for k in period:
                        out.append(lines [i + k])


                if period == 1:
                        out.append("... the line above appears %d times in a row ..." % runs)
                else:
                        out.append("... the %d lines above appear %d times in a row ..."
                                % [period, runs])
                i += period * runs
        return out


func _block_matches(lines: PackedStringArray, a: int, b: int, p: int) -> bool:
        if b + p > lines.size():
                return false
        for k in p:
                if lines [a + k] != lines [b + k]:
                        return false
        return true


func _summarise(text: String) -> String:
        if text == "":
                return ""


        if "VkResult error -10" in text:
                return "GPU ran out of memory allocations (Vulkan VK_ERROR_TOO_MANY_OBJECTS)"
        if "VkResult error -2)" in text:
                return "GPU ran out of video memory (Vulkan VK_ERROR_OUT_OF_DEVICE_MEMORY)"
        if "0x887a0005" in text:
                return "GPU device removed (D3D12 DXGI_ERROR_DEVICE_REMOVED)"
        var lines:= text.split("\n", false)
        for i in range(lines.size() - 1, -1, -1):
                var line:= lines [i].strip_edges()
                if line.begins_with("ERROR:") or line.begins_with("SCRIPT ERROR:") or line.begins_with("FATAL:") or line.begins_with("USER ERROR:"):
                        return line.left(300)
        return ""


func _quiet_summary(session: Dictionary) -> String:
        if session.has("quitting"):
                return "stopped while quitting"
        if bool(session.get("loading", false)):
                return "stopped on the loading screen at %d%%" % int(round(float(session.get("progress", 0.0)) * 100.0))
        return ""


func _compose(session: Dictionary, crashed: bool, started: float,
                died_at: float, text: String, error: String) -> String:
        var rows:= [


                ["when", Time.get_datetime_string_from_unix_time(int(died_at), true)
                        + " UTC, last seen alive" if died_at > 0.0 else "unknown"],
                ["ended", "a fault the engine's crash handler caught"
                        if crashed else "no shutdown, and no crash handler either"],
                ["ran for", _duration(started, died_at)],
                ["build", str(session.get("build", _build_string()))],
                ["engine", str(session.get("engine", Engine.get_version_info().get("string", "")))],
                ["platform", "%s %s" % [session.get("platform", OS.get_name()),
                        session.get("os_version", "")]],


                ["cpu", "%s (%d threads)" % [_told(session.get("cpu", "")),
                        int(session.get("threads", 0))]],
                ["memory", "%s GB" % session.get("memory_gb", 0)],
                ["gpu", _told("%s %s" % [session.get("gpu", ""),
                        session.get("vendor", "")])],


                ["gpu driver", _told(session.get("gpu_driver", ""))
                        if session.has("gpu_driver") else "not recorded by this build"],
                [_api_label(str(session.get("backend", ""))),
                        _told(session.get("api", session.get("driver", "")))],
                ["renderer", _told(session.get("renderer", ""))
                        + ("" if not session.has("renderer_project")
                                or str(session.get("renderer_project", ""))
                                        == str(session.get("renderer", ""))
                                else " (project asked for %s)" % _told(str(
                                        session.get("renderer_project", ""))))],
        ]

        if session.has("backend"):
                rows.append(["backend", "%s (settings asked for %s)" % [_told(session.get("backend", "")),
                        _told(session.get("backend_chosen", ""))]])
        if session.has("render_thread"):
                rows.append(["render thread", "%s (settings asked for %s)" % [
                        "on" if bool(session.get("render_thread")) else "off",
                        _told(session.get("render_thread_chosen", ""))]])


        if session.has("stage"):
                rows.append(["last step", "%s (%d%%)%s" % [str(session.get("stage")),
                        int(round(float(session.get("progress", 0.0)) * 100.0)),
                        "" if bool(session.get("loading", false)) else ", screen closed"]])


        if session.has("doing"):
                rows.append(["last action", str(session.get("doing"))
                        + _before_the_end(float(session.get("doing_at", 0.0)), died_at)])
        if session.has("pile"):
                rows.append(["pile", str(session.get("pile"))])
        if session.has("quitting"):
                rows.append(["quitting", "yes, the window had been asked to close"])
        if error != "":
                rows.append(["last error", error])


        rows.append_array(windows_rows)
        if saved_log != "":


                rows.append(["log kept", saved_log.get_file()])

        var out:= ""


        if intel_fault != "":
                out += "!! INTEL CPU WITH A KNOWN FAULT: %s\n" % intel_fault
                out += "!! Intel 13th and 14th gen desktop chips can crash any game (Intel's\n"
                out += "!! \"Vmin Shift Instability\"). The Intel channel on the Discord explains the issue.\n"
                out += "\n"
        out += "FIND THE NEEDLE crash report\n"
        out += "============================\n"
        for row in rows:
                out += "%-13s %s\n" % [row [0], row [1]]
        out += "\n"
        if text == "":
                out += ("No log survived this crash. The engine keeps only the last few\n"
                        + "and rotates one out per launch, so relaunching several times\n"
                        + "before opening this window can lose it.\n")
        else:
                out += "==== log ====================================================\n"
                out += text


        out = _scrub(out)
        if out.length() > MAX_REPORT:


                out = out.left(MAX_REPORT) + "\n... trimmed here ...\n"
        return out


func _scrub(text: String) -> String:
        var out:= text
        for key: String in ["USERPROFILE", "HOME"]:
                var home:= OS.get_environment(key)


                if home.length() < 4:
                        continue
                out = out.replace(home, "<home>")
                out = out.replace(home.replace("\\", "/"), "<home>")
        return out


static func _gpu_driver() -> String:
        var info:= OS.get_video_adapter_driver_info()
        if info.size() < 2 or info [1].strip_edges() == "":
                return ""
        return driver_label(info [0].strip_edges(), info [1].strip_edges())


static func driver_label(maker: String, version: String) -> String:
        var parts:= version.split(".")
        if maker.to_lower().contains("nvidia") and parts.size() == 4:
                var digits:= (parts [2] + parts [3].lpad(4, "0")).right(5)
                if digits.length() == 5 and digits.is_valid_int():
                        return "%s %s.%s (%s)" % [maker, digits.left(3), digits.right(2), version]
        return "%s %s" % [maker, version]


static func _api_label(backend: String) -> String:
        match backend:
                "d3d12":
                        return "d3d12 level"
                "opengl3":
                        return "opengl"
                _:
                        return "vulkan"


func _told(value: Variant) -> String:
        var s:= str(value).strip_edges()
        return s if s != "" else "not reported"


func _duration(started: float, ended: float) -> String:


        if started <= 0.0 or ended < started - 2.0:
                return "unknown"
        var secs:= maxi(0, int(ended - started))
        if secs < 60:
                return "%d seconds" % secs
        if secs < 3600:
                return "%d minutes" % (secs / 60)
        return "%dh %02dm" % [secs / 3600, (secs % 3600) / 60]


func _before_the_end(at: float, died_at: float) -> String:
        if at <= 0.0 or died_at <= 0.0 or at > died_at + 2.0:
                return ""
        var secs:= maxi(0, int(died_at - at))
        if secs < 60:
                return " (%d s before the end)" % secs
        if secs < 3600:
                return " (%d minutes before the end)" % (secs / 60)
        return " (%dh %02dm before the end)" % [secs / 3600, (secs % 3600) / 60]


func _build_string() -> String:
        return Cfg.build_string()


func _physical_memory_gb() -> float:
        var info:= OS.get_memory_info()
        var bytes:= float(info.get("physical", 0))


        return snappedf(bytes / 1073741824.0, 0.1) if bytes > 0.0 else 0.0


func _start_windows_events() -> void:
        if OS.get_name() != "Windows" or _recovered.is_empty():
                return
        var session: Dictionary = _recovered.session
        windows_rows = [["windows", "still being read"]]
        _recompose()
        _events_thread = Thread.new()


        _events_thread.start(_windows_events_job.bind(float(_recovered.started),
                float(_recovered.died_at), int(session.get("pid", 0)),
                str(session.get("exe", OS.get_executable_path().get_file())),
                Time.get_unix_time_from_system()))


func _await_windows_events() -> void:
        if _events_thread == null:
                return
        var give_up:= Time.get_ticks_msec() + WINDOWS_WAIT_MS
        _reading_windows = true
        while _events_thread.is_alive() and Time.get_ticks_msec() < give_up:
                await get_tree().process_frame
        _reading_windows = false
        if _events_thread.is_alive():

                windows_rows = [["windows", "no answer within %d s" % (WINDOWS_WAIT_MS / 1000)]]
        else:
                windows_rows = _events_thread.wait_to_finish()
                _events_thread = null
        _recompose()


func _recompose() -> void:
        if _recovered.is_empty():
                return
        pending = _compose(_recovered.session, _recovered.crashed, _recovered.started,
                _recovered.died_at, _recovered.text, _recovered.error)
        pending_changed.emit()


func _windows_events_job(started: float, died_at: float, pid: int, exe: String,
                now: float) -> Array:
        var ended:= died_at if died_at > 0.0 else now


        var app:= _wevtutil("Application", 10, windows_app_query(exe, started - 60.0))
        var gpu:= _wevtutil("System", WINDOWS_GPU_EVENTS,
                windows_gpu_query(started, ended + WINDOWS_GPU_AFTER))
        var rows:= windows_event_rows(str(app.xml), str(gpu.xml), died_at, pid)
        for res: Dictionary in [app, gpu]:
                if not res.ok:
                        rows.append(["windows", "could not be read (%s)" % res.why])


        if rows.is_empty():
                rows.append(["windows", "no crash, freeze or GPU reset on record for this run"])
        return rows


static func _wevtutil(log_name: String, count: int, query: String) -> Dictionary:
        var root:= OS.get_environment("SystemRoot")
        var exe:= root + "\\System32\\wevtutil.exe" if root != "" else "wevtutil.exe"
        var out:= []
        var code:= OS.execute(exe, ["qe", log_name, "/c:%d" % count, "/rd:true",
                "/q:" + query], out)
        if code != 0:
                return { "ok": false, "xml": "", "why": "wevtutil %s exit %d" % [log_name, code] }
        return { "ok": true, "xml": "".join(out), "why": "" }


static func windows_app_query(exe: String, from: float) -> String:
        var q:= ("*[System[(Provider[@Name='Application Error'] or Provider[@Name='Application Hang'])"
                + " and TimeCreated[@SystemTime>='%s']]]") % _event_time(from)
        if exe != "" and not "'" in exe:
                q += " and *[EventData[Data[@Name='AppName']='%s']]" % exe
        return q


static func windows_gpu_query(from: float, to: float) -> String:
        var sources:= PackedStringArray()
        for source: String in WINDOWS_GPU_SOURCES:
                sources.append("Provider[@Name='%s']" % source)
        sources.append("(Provider[@Name='Display'] and EventID=4101)")
        return "*[System[(%s) and TimeCreated[@SystemTime>='%s' and @SystemTime<='%s']]]" % [" or ".join(sources), _event_time(from), _event_time(to)]


static func _event_time(unix: float) -> String:
        return Time.get_datetime_string_from_unix_time(int(unix)) + ".000Z"


static func windows_event_rows(app_xml: String, gpu_xml: String, died_at: float,
                pid: int) -> Array:
        var rows: Array = []
        for e: Dictionary in _events_of(app_xml):
                var d: Dictionary = e.data
                var theirs:= _event_pid(str(d.get("ProcessId", "")))
                if pid > 0 and theirs > 0 and theirs != pid:
                        continue
                var when:= _since(float(e.at), died_at)
                if e.provider == "Application Error":
                        var module:= ("%s %s" % [d.get("ModuleName", "?"),
                                d.get("ModuleVersion", "")]).strip_edges()
                        rows.append(["windows", "crashed in %s, code 0x%s at offset 0x%s%s" % [module,
                                _bare_hex(str(d.get("ExceptionCode", ""))),
                                _bare_hex(str(d.get("FaultingOffset", ""))), when]])
                elif e.provider == "Application Hang":
                        var kind:= str(d.get("HangType", ""))
                        rows.append(["windows", "stopped responding and was closed%s%s" % [
                                "" if kind in ["", "Unknown"] else " (hang type %s)" % kind, when]])
                if rows.size() >= WINDOWS_APP_EVENTS:
                        break
        var gpu: Array = []
        for e: Dictionary in _events_of(gpu_xml):


                var said:= PackedStringArray()
                for v: String in e.values:
                        if v != "" and not "\\" in v:
                                said.append(v)
                var what:= "%s %d" % [e.provider, e.id]
                if e.provider == "Display":
                        what += ", the driver stopped responding and was recovered"
                if not said.is_empty():
                        what += ": " + "; ".join(said).left(160)
                gpu.append(["gpu event", what + _since(float(e.at), died_at)])

        rows.reverse()
        gpu.reverse()
        rows.append_array(gpu)
        return rows


static func _events_of(xml: String) -> Array:
        var out: Array = []
        var provider:= RegEx.create_from_string("<Provider Name='([^']*)'")
        var number:= RegEx.create_from_string("<EventID[^>]*>(\\d+)</EventID>")
        var clock:= RegEx.create_from_string("SystemTime='([^'.Z]*)")
        var named:= RegEx.create_from_string("<Data Name='([^']*)'>([^<]*)</Data>")
        var bare:= RegEx.create_from_string("<Data>([^<]*)</Data>")
        for block in xml.split("</Event>", false):
                var p:= provider.search(block)
                if p == null:
                        continue
                var e:= { "provider": p.get_string(1), "id": 0, "at": 0.0, "data": { },
                        "values": PackedStringArray() }
                var m:= number.search(block)
                if m != null:
                        e.id = int(m.get_string(1))
                m = clock.search(block)
                if m != null:
                        e.at = float(Time.get_unix_time_from_datetime_string(m.get_string(1)))
                for d in named.search_all(block):
                        e.data [d.get_string(1)] = _xml_text(d.get_string(2))
                for d in bare.search_all(block):
                        e.values.append(_xml_text(d.get_string(1)))
                out.append(e)
        return out


static func _xml_text(s: String) -> String:
        return s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'").replace("&amp;", "&").strip_edges()


static func _event_pid(s: String) -> int:
        if s.begins_with("0x"):
                return s.hex_to_int()
        return int(s) if s.is_valid_int() else 0


static func _bare_hex(s: String) -> String:
        var h:= s.trim_prefix("0x").lstrip("0")
        return h if h != "" else "0"


static func _since(at: float, died_at: float) -> String:
        if at <= 0.0 or died_at <= 0.0:
                return ""
        var secs:= int(round(at - died_at))
        var n:= absi(secs)
        var span:= "%d s" % n if n < 60 else "%d minutes" % (n / 60) if n < 3600 else "%dh %02dm" % [n / 3600, (n % 3600) / 60]
        return " (%s %s it was last seen)" % [span, "after" if secs >= 0 else "before"]


func submit() -> Dictionary:
        if pending == "":
                return { "ok": false, "error": "there is nothing to send" }
        if sent:
                return { "ok": true, "error": "" }
        sending = true
        send_started.emit()
        var res: Dictionary = await Leaderboard.authed_rpc("report_crash", {
                "p_report": pending,
                "p_summary": pending_summary,
                "p_reason": pending_reason,
                "p_build": _build_string(),
                "p_platform": OS.get_name(),
                "p_gpu": RenderingServer.get_video_adapter_name(),
        })
        sending = false
        last_error = "" if res.ok else str(res.error)
        if res.ok:
                sent = true
        send_finished.emit(bool(res.ok), last_error)
        return { "ok": res.ok, "error": str(res.error) }


func _auto_send() -> void:


        await get_tree().process_frame
        await _await_windows_events()
        await submit()


func crash_folder() -> String:
        DirAccess.make_dir_recursive_absolute(CRASH_DIR)
        return ProjectSettings.globalize_path(CRASH_DIR)


func fake_pending(text: String) -> void:
        pending = text
        pending_reason = REASON_QUIET
        pending_summary = "ERROR: a made up error, from the crash dialogue probe"
        sent = false
