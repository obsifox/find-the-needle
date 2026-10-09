extends Node

## GameLog (v2.4.0) -- a log that SURVIVES crashes and that a human can find.
##
## Why this exists: the v2.3.0 crash reports said "No log survived this
## crash". Two reasons:
##   1) engine file logging was never actually on -- project.godot carried
##      a bogus key ("debug/file_logging/max_log_files"), so Godot never
##      created user://logs/godot.log and crash_report had nothing to quote;
##   2) everything that WAS written lived inside the app's private storage,
##      invisible to any file manager on the phone.
##
## What this does, from the first frame of every launch:
##   - appends an add-only, flushed-after-every-line game log to
##     user://gamelog.log (kept across runs, rotated at 3 MB);
##   - mirrors the same log + crash artifacts into the phone's SHARED
##     storage, first writable path wins, probed again every launch:
##       /storage/emulated/0/.gamelog/            <- what the player asked
##           for; becomes writable once "All files access" is granted in
##           App info -> Permissions -> Files and media
##       /storage/emulated/0/Android/media/com.obsifox.findtheneedle/gamelog/
##           <- always writable, visible to every file manager and PC/USB
##       /storage/emulated/0/Android/data/com.obsifox.findtheneedle/files/gamelog/
##           <- extra fallback
##   - logs boot info (build, GPU, renderer, driver API), app lifecycle
##     (pause/resume/focus/close/native-crash stamp) and the loading
##     breadcrumbs routed through CrashReport.
##
## After a crash the player opens a file manager, goes to .gamelog (or
## Android/media/com.obsifox.findtheneedle/gamelog) and sends gamelog.txt
## plus engine_prev.log / crash_report_*.txt.

const MIRROR_ROOTS: Array[String] = [
        "/storage/emulated/0/.gamelog",
        "/storage/emulated/0/Android/media/com.obsifox.findtheneedle/gamelog",
        "/storage/emulated/0/Android/data/com.obsifox.findtheneedle/files/gamelog",
]

const LOCAL_PATH := "user://gamelog.log"
const LOCAL_OLD_PATH := "user://gamelog.old.log"
const LOCAL_MAX_BYTES := 3 * 1024 * 1024

const MIRROR_NAME := "gamelog.txt"
const README_NAME := "README.txt"
const PREV_ENGINE_NAME := "engine_prev.log"

const ARTIFACT_DIR := "user://gamelog_artifacts"


var mirror_root := ""
var local_ok := false
var mirror_ok := false


var _local: FileAccess = null
var _mirror: FileAccess = null


func _ready() -> void:
        _rotate_local()
        _open_local()
        _probe_mirror()
        _open_mirror()
        call_deferred("_write_head")
        call_deferred("_write_readme")


func _exit_tree() -> void:
        put("life", "GameLog closing")
        if _local != null:
                _local.flush()
        if _mirror != null:
                _mirror.flush()


func _notification(what: int) -> void:
        match what:
                NOTIFICATION_APPLICATION_PAUSED:
                        put("life", "app PAUSED -- the system may kill it at any moment")
                NOTIFICATION_APPLICATION_RESUMED:
                        put("life", "app resumed")
                NOTIFICATION_APPLICATION_FOCUS_OUT:
                        put("life", "window focus lost")
                NOTIFICATION_APPLICATION_FOCUS_IN:
                        put("life", "window focus regained")
                NOTIFICATION_WM_CLOSE_REQUEST:
                        put("life", "close requested")
                NOTIFICATION_CRASH:
                        put("crash", "!!! engine crash handler fired (NOTIFICATION_CRASH)")


## -- public API -----------------------------------------------------------


func put(tag: String, msg: String) -> void:
        _write_now("[%s] %s" % [tag, msg])


func err(tag: String, msg: String) -> void:
        put(tag, "! " + msg)


## Writes a text artifact (e.g. a composed crash report) both to the app's
## own artifact folder and, if available, to the shared mirror folder.
func write_artifact(name: String, text: String) -> void:
        DirAccess.make_dir_recursive_absolute(ARTIFACT_DIR)
        var f := FileAccess.open(ARTIFACT_DIR.path_join(name), FileAccess.WRITE)
        if f != null:
                f.store_string(text)
                f.close()
        if mirror_root != "":
                var m := FileAccess.open(mirror_root.path_join(name), FileAccess.WRITE)
                if m != null:
                        m.store_string(text)
                        m.close()
        put("log", "artifact %s written%s" % [name,
                (" to " + mirror_root) if mirror_root != "" else " (app storage only)"])


## Copies an existing file (e.g. the engine log of the run that died) to the
## same two places write_artifact() uses.
func mirror_file(src: String, dst_name: String) -> void:
        DirAccess.make_dir_recursive_absolute(ARTIFACT_DIR)
        if DirAccess.copy_absolute(src, ARTIFACT_DIR.path_join(dst_name)) == OK \
                        and mirror_root != "":
                DirAccess.copy_absolute(src, mirror_root.path_join(dst_name))


## -- internals ------------------------------------------------------------


func _write_now(body: String) -> void:
        var line := "[%s] %s" % [Time.get_datetime_string_from_system(true, false), body]
        if _local != null:
                _local.store_line(line)
                _local.flush()
        else:
                local_ok = false
        if _mirror != null:
                _mirror.store_line(line)
                _mirror.flush()
        print(line)


func _rotate_local() -> void:
        if not FileAccess.file_exists(LOCAL_PATH):
                return
        var f := FileAccess.open(LOCAL_PATH, FileAccess.READ)
        if f == null:
                return
        var size := f.get_length()
        f.close()
        if size <= LOCAL_MAX_BYTES:
                return
        DirAccess.remove_absolute(LOCAL_OLD_PATH)
        DirAccess.rename_absolute(LOCAL_PATH, LOCAL_OLD_PATH)


func _open_local() -> void:
        _local = FileAccess.open(LOCAL_PATH,
                FileAccess.READ_WRITE if FileAccess.file_exists(LOCAL_PATH) else FileAccess.WRITE)
        if _local != null:
                _local.seek_end()
                local_ok = true


## Probes the shared-storage candidates. Runs every launch: if the player
## grants "All files access" later, the preferred folder starts working on
## the next run without any code change.
func _probe_mirror() -> void:
        if OS.get_name() != "Android" and OS.get_name() != "iOS":
                return
        for root in MIRROR_ROOTS:
                if DirAccess.make_dir_recursive_absolute(root) != OK:
                        continue
                var probe := root.path_join(".probe.tmp")
                var f := FileAccess.open(probe, FileAccess.WRITE)
                if f == null:
                        continue
                f.close()
                DirAccess.remove_absolute(probe)
                mirror_root = root
                mirror_ok = true
                return


func _open_mirror() -> void:
        if mirror_root == "":
                return
        var path := mirror_root.path_join(MIRROR_NAME)
        _mirror = FileAccess.open(path,
                FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
        if _mirror != null:
                _mirror.seek_end()
        else:
                mirror_ok = false


## Boot header. Deferred so the other autoloads (Cfg especially) exist.
func _write_head() -> void:
        var gpu := RenderingServer.get_video_adapter_name()
        var vendor := RenderingServer.get_video_adapter_vendor()
        var lines: Array[String] = []
        lines.append("=".repeat(72))
        lines.append("LAUNCH %s (unix %d)" % [
                Time.get_datetime_string_from_system(true, false),
                int(Time.get_unix_time_from_system())])
        lines.append("build     %s" % Cfg.build_string())
        lines.append("platform  %s %s" % [OS.get_name(), OS.get_version()])
        lines.append("locale    %s" % OS.get_locale())
        lines.append("cpu       %s (%d threads)" % [OS.get_processor_name(),
                OS.get_processor_count()])
        lines.append("gpu       %s %s" % [gpu, vendor])
        lines.append("driver    %s (api %s)" % [
                RenderingServer.get_current_rendering_driver_name(),
                RenderingServer.get_video_adapter_api_version()])
        lines.append("renderer  %s (project %s / mobile override %s)" % [
                RenderingServer.get_current_rendering_method(),
                str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
                str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))])
        var mem: Dictionary = OS.get_memory_info()
        lines.append("memory    %.1f GB physical" % (float(mem.get("physical", 0)) / 1073741824.0))
        lines.append("log file  %s" % ProjectSettings.globalize_path(LOCAL_PATH))
        if mirror_root != "":
                lines.append("mirror    %s" % mirror_root)
        else:
                lines.append("mirror    (none: no shared-storage path was writable)")
        put("boot", "\n".join(lines))
        if mirror_root != "":
                put("boot", "after a crash: send %s from %s" % [MIRROR_NAME, mirror_root])
        _copy_previous_engine_logs()


## The engine's own log of the run that died. With engine file logging now
## enabled (v2.4.0), user://logs holds rotated copies of earlier runs; the
## newest non-live one is the previous run. Mirroring it means a hard crash
## (dead driver, no dialog) still leaves the SCRIPT ERROR / pipeline trail
## where the player can grab it.
func _copy_previous_engine_logs() -> void:
        var dir := DirAccess.open("user://logs")
        if dir == null:
                return
        var best := ""
        var best_time := 0
        for name in dir.get_files():
                if name == "godot.log":
                        continue
                var path := "user://logs".path_join(name)
                var stamp := FileAccess.get_modified_time(path)
                if stamp > best_time:
                        best_time = stamp
                        best = path
        if best != "":
                mirror_file(best, PREV_ENGINE_NAME)
                put("log", "mirrored previous engine log: %s" % best)


func _write_readme() -> void:
        if mirror_root == "":
                return
        var f := FileAccess.open(mirror_root.path_join(README_NAME), FileAccess.WRITE)
        if f == null:
                return
        f.store_string("""FIND THE NEEDLE -- game logs / لاگ‌های بازی

gamelog.txt           the running game log -- send this one first
engine_prev.log       the previous run's engine log (Godot's own log)
crash_report_*.txt    composed crash reports from runs that died

After a crash: just copy the NEWEST files from this folder and send them.

fa:
بعد از کرش، فقط جدیدترین فایل‌های همین پوشه را کپی کنید و بفرستید.
gamelog.txt = لاگ اصلی بازی. اگر این پوشه خالی بود، لاگ‌ها در
Android/media/com.obsifox.findtheneedle/gamelog نوشته می‌شوند.
برای فعال شدن همین پوشه در روت حافظه: Settings -> Apps -> Find The Needle
-> Permissions -> Files and media -> Allow management of all files.
""")
        f.close()
