class_name GlintProbe
extends Node


const OUT_DIR:= "res://captures"
const WATCH_SECONDS:= 10.0
const SHOTS:= 3

const SHOT_FLOOR:= 0.25

var background: MenuBackground


static var _already_ran:= false


func _ready() -> void:
	if _already_ran:
		queue_free()
		return
	_already_ran = true
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	for i in 20:
		await get_tree().process_frame

	var shots:= 0
	var glints:= 0
	var elapsed:= 0.0
	var previous:= 0.0
	var rising:= false
	var lit_frames:= 0
	var frames:= 0
	var brightest:= 0.0
	var framed:= true

	while elapsed < WATCH_SECONDS:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		frames += 1
		var hot: float = background.get("_glint_hot")
		brightest = maxf(brightest, hot)
		if hot > 0.02:
			lit_frames += 1


		if hot > previous:
			rising = true
		elif rising and previous > SHOT_FLOOR:
			rising = false
			glints += 1
			print("[glint] %5.2fs  peak %.2f" % [elapsed, previous])
			framed = _check_framed() and framed
			if shots < SHOTS:
				shots += 1
				_shoot("glint_%02d" % shots)
		previous = hot


	var duty:= float(lit_frames) / maxf(float(frames), 1.0)
	var ok:= true
	ok = _check(glints >= 2, "the glint fires more than once in %.0fs (saw %d)"
		% [WATCH_SECONDS, glints]) and ok
	ok = _check(brightest > 0.8, "and reaches full alignment (best %.2f)" % brightest) and ok
	ok = framed and ok
	ok = _check(duty < 0.5, "and is dark most of the time (lit %.0f%% of frames)"
		% (duty * 100.0)) and ok
	print("[glint] %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit()


func _check_framed() -> bool:
	var overlay: ColorRect = background.get("_overlay")
	if not _check(overlay.visible, "the lens flare is drawn when the glint fires"):
		return false
	var at: Vector2 = overlay.material.get_shader_parameter("flare_pos")
	return _check(at.x > 0.05 and at.x < 0.95 and at.y > 0.05 and at.y < 0.95,
		"and lands inside the frame (at %.2f, %.2f)" % [at.x, at.y])


func _shoot(shot_name: String) -> void:
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s.png" % [OUT_DIR, shot_name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("[glint] %s  %dx%d" % [path, img.get_width(), img.get_height()])


func _check(condition: bool, what: String) -> bool:
	if not condition:
		push_error("[glint] FAILED: %s" % what)
		print("[glint]   no: %s" % what)
	return condition
