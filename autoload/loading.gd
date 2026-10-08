extends CanvasLayer


const LAYER:= 128

const COL_TITLE:= Color(1.0, 0.86, 0.34)
const COL_TEXT:= Color(0.95, 0.96, 0.99)
const COL_DIM:= Color(0.7, 0.73, 0.79)
const COL_BACK:= Color(0.02, 0.02, 0.03, 1.0)


const BACKDROP_PATH:= "res://assets/branding/loading_backdrop.jpg"


const COL_BAR:= Color(0.84, 0.66, 0.28)
const COL_BAR_BACK:= Color(1.0, 1.0, 1.0, 0.08)

const MARGIN_L:= 76.0
const BAR_W:= 620.0
const BAR_H:= 6.0


const SPIN_RADIUS:= 10.0
const SPIN_WIDTH:= 3.0
const SPIN_GAP:= 20.0
const SPIN_TURNS_PER_SECOND:= 0.8


const FADE_OUT:= 0.5


const TIP_MIN_SECONDS:= 6.0
const TIP_MAX_SECONDS:= 14.0
const TIP_CHARS_PER_SECOND:= 14.0
const TIP_READ_START:= 2.0

const TIP_FADE:= 0.3


const CLOSE_AGAIN_FRAMES:= 2
const CLOSE_AGAIN_MS:= 400

var _root: Control
var _back: ColorRect
var _title: Label
var _caption: Label
var _tip: Label
var _bar_back: ColorRect
var _bar_fill: ColorRect
var _percent: Label
var _spinner: Control
var _tween: Tween


var _target:= 0.0
var _shown:= 0.0
var _active:= false


var _tip_bag: Array [int] = []
var _tip_rng:= RandomNumberGenerator.new()

var _tip_left:= 0.0


var _tip_alpha:= 1.0
var _tip_out:= false

var _close_note: Label


var _close_held_frame:= -1
var _close_held_msec:= 0

var _accept_quit_before:= true

var _letting_go:= false


var _gpu_allocs:= "--gpuallocs" in OS.get_cmdline_user_args()


const SLOW_FRAME_MS:= 1000.0


var _steps: Dictionary = { }


var _body:= ""

var _mark_usec:= 0
var _pre_draw_usec:= 0
var _frame_script:= 0.0

var _compiles_seen:= Vector2i.ZERO


func _ready() -> void:
	layer = LAYER
	_tip_rng.randomize()


	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.name = "LoadingRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_back = ColorRect.new()
	_back.color = COL_BACK
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_back)


	if ResourceLoader.exists(BACKDROP_PATH):
		var plate:= TextureRect.new()
		plate.texture = load(BACKDROP_PATH)
		plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(plate)


	_title = _make_label(34, COL_TITLE, true)

	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_place(_title, -212.0, -168.0)

	_caption = _make_label(20, COL_TEXT)
	_place(_caption, -152.0, -124.0)

	_bar_back = ColorRect.new()
	_bar_back.color = COL_BAR_BACK
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_bar_back, -112.0, -112.0 + BAR_H, BAR_W)
	_root.add_child(_bar_back)

	_bar_fill = ColorRect.new()
	_bar_fill.color = COL_BAR
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_bar_fill, -112.0, -112.0 + BAR_H, 0.0)
	_root.add_child(_bar_fill)

	_percent = _make_label(16, COL_DIM)
	_place(_percent, -112.0, -88.0, BAR_W)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


	_spinner = Control.new()
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spin_box:= (SPIN_RADIUS + SPIN_WIDTH) * 2.0
	var bar_mid:= -112.0 + BAR_H * 0.5
	_place(_spinner, bar_mid - spin_box * 0.5, bar_mid + spin_box * 0.5, spin_box)
	_spinner.offset_left = MARGIN_L + BAR_W + SPIN_GAP
	_spinner.offset_right = _spinner.offset_left + spin_box
	_spinner.draw.connect(_draw_spinner)
	_root.add_child(_spinner)

	_tip = _make_label(17, COL_DIM)

	_place(_tip, -72.0, -20.0, BAR_W * 1.4)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_close_note = _make_label(17, COL_TITLE)
	_place(_close_note, -72.0, -20.0, BAR_W * 1.4)
	_close_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_close_note.visible = false


func _make_label(size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.style(l, size, colour, 5, heavy)
	_root.add_child(l)
	return l


func _place(c: Control, top: float, bottom: float, width: float = BAR_W) -> void:
	c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	c.offset_left = MARGIN_L
	c.offset_right = MARGIN_L + width
	c.offset_top = top
	c.offset_bottom = bottom


func show_screen(title: String, caption: String = "") -> void:


	if not _active:
		_accept_quit_before = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_close_held_frame = -1
	_close_note.visible = false
	_active = true
	_target = 0.0
	_shown = 0.0
	_steps.clear()
	_body = caption
	_compiles_seen = _pipeline_counts()
	_mark_usec = Time.get_ticks_usec()
	_pre_draw_usec = 0
	_title.text = title
	_caption.text = caption

	_tip.visible = Cfg.show_tips
	_put_tip(GameTips.draw(_tip_bag, _tip_rng))
	_tip_out = false
	_tip_alpha = 1.0
	_tip.modulate.a = 1.0
	_apply_bar()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_root.visible = true
	_root.modulate.a = 1.0


func enter_scene(path: String) -> void:
	var err:= ResourceLoader.load_threaded_request(path)
	var status:= ResourceLoader.THREAD_LOAD_FAILED
	if err == OK:
		status = ResourceLoader.load_threaded_get_status(path)
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
			status = ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var scene:= ResourceLoader.load_threaded_get(path) as PackedScene
		if scene != null:
			get_tree().change_scene_to_packed(scene)
			return
	push_warning("Loading.enter_scene: threaded load of %s failed, loading it in one go" % path)
	get_tree().change_scene_to_file(path)


func step(caption: String, progress: float) -> void:
	if not _active:
		return
	if _gpu_allocs:
		_print_gpu_allocs(_caption.text)
	_caption.text = caption


	_target = clampf(maxf(progress, _target), 0.0, 1.0)
	CrashReport.note_stage(caption, _target)


func hide_screen() -> void:
	if not _active:
		return
	_print_timing()
	if _gpu_allocs:
		_print_gpu_allocs(_caption.text)
		var rd:= RenderingServer.get_rendering_device()
		if rd != null:
			print(rd.get_driver_and_device_memory_report())


		var found:= { }
		_collect_textures(get_tree().root, found, { }, 0)
		var usage: Array = found.values()
		usage.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a ["bytes"] > b ["bytes"])
		var total:= 0
		for t: Dictionary in usage:
			total += int(t ["bytes"])
		print("[tex] %d textures, %.0f MB" % [usage.size(), total / 1048576.0])
		for t: Dictionary in usage.slice(0, 40):
			print("[tex] %7.1f MB  %5dx%-5d fmt %-3d  %s" % [int(t ["bytes"]) / 1048576.0,
				t ["width"], t ["height"], t ["format"], t ["path"]])


		# BUGFIX (mobile): the gpu-allocs dump used to quit the whole app right
		# after the loading screen finished -- on phones this looked like
		# "the game closes when loading completes". Never quit here.
		if not Cfg.is_mobile:
			get_tree().quit()
	_active = false
	get_tree().auto_accept_quit = _accept_quit_before
	_close_note.visible = false
	CrashReport.note_stage("loading screen closed", 1.0, false)
	_target = 1.0
	_shown = 1.0
	_apply_bar()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func() -> void: _root.visible = false)


func note_gpu(label: String) -> void:
	if _gpu_allocs:
		_print_gpu_allocs(label)


func _print_gpu_allocs(step_name: String) -> void:
	var rd:= RenderingServer.get_rendering_device()
	if rd == null:
		return
	var parts: Array [String] = []
	for i in rd.get_tracked_object_type_count():
		var drv:= rd.get_driver_allocs_by_object_type(i)
		var dev:= rd.get_device_allocs_by_object_type(i)
		if drv > 0 or dev > 0:
			parts.append("%s %d/%d" % [rd.get_tracked_object_name(i), drv, dev])
	print("[gpu] %-26s device %d, driver %d, video %.0f MB, buffers %.0f MB, textures %.0f MB | %s" % [
		step_name, rd.get_device_allocation_count(), rd.get_driver_allocation_count(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		", ".join(parts)])


func _collect_textures(obj: Object, found: Dictionary, seen: Dictionary, depth: int) -> void:
	if obj == null or not is_instance_valid(obj) or depth > 8:
		return
	var id:= obj.get_instance_id()
	if seen.has(id):
		return
	seen [id] = true
	if obj is Texture:
		_note_texture(obj as Texture, found)
		return
	if obj is Script:
		return
	for prop: Dictionary in obj.get_property_list():
		var t: int = prop ["type"]
		if t == TYPE_OBJECT or t == TYPE_ARRAY or t == TYPE_DICTIONARY:
			_collect_value(obj.get(prop ["name"]), found, seen, depth + 1)
	if obj is Node:


		for child in (obj as Node).get_children(true):
			_collect_textures(child, found, seen, 0)


func _collect_value(v: Variant, found: Dictionary, seen: Dictionary, depth: int) -> void:
	match typeof(v):
		TYPE_OBJECT:


			if is_instance_valid(v) and not (v is Node):
				_collect_textures(v, found, seen, depth)
		TYPE_ARRAY:
			for e: Variant in v:
				_collect_value(e, found, seen, depth)
		TYPE_DICTIONARY:
			for e: Variant in (v as Dictionary).values():
				_collect_value(e, found, seen, depth)


func _note_texture(tex: Texture, found: Dictionary) -> void:
	var rid:= tex.get_rid()
	if not rid.is_valid() or found.has(rid):
		return
	var w:= 0
	var h:= 0
	var layers:= 1
	if tex is Texture2D:
		w = (tex as Texture2D).get_width()
		h = (tex as Texture2D).get_height()
	elif tex is TextureLayered:
		w = (tex as TextureLayered).get_width()
		h = (tex as TextureLayered).get_height()
		layers = (tex as TextureLayered).get_layers()
	elif tex is Texture3D:
		w = (tex as Texture3D).get_width()
		h = (tex as Texture3D).get_height()
		layers = (tex as Texture3D).get_depth()
	var fmt:= RenderingServer.texture_get_format(rid)
	var path:= tex.resource_path
	if path == "":
		path = RenderingServer.texture_get_path(rid)
	if path == "":
		path = "(%s)" % tex.get_class()

	found [rid] = { "bytes": int(w * h * layers * _bytes_per_pixel(fmt) * 4.0 / 3.0),
		"width": w, "height": h, "format": fmt, "path": path }


func _bytes_per_pixel(fmt: int) -> float:
	if fmt in [Image.FORMAT_DXT1, Image.FORMAT_RGTC_R]:
		return 0.5
	if fmt in [Image.FORMAT_DXT3, Image.FORMAT_DXT5, Image.FORMAT_RGTC_RG,
			Image.FORMAT_BPTC_RGBA, Image.FORMAT_BPTC_RGBF, Image.FORMAT_BPTC_RGBFU,
			Image.FORMAT_L8, Image.FORMAT_R8]:
		return 1.0
	if fmt in [Image.FORMAT_LA8, Image.FORMAT_RG8, Image.FORMAT_RH,
			Image.FORMAT_RGB565, Image.FORMAT_RGBA4444]:
		return 2.0
	if fmt in [Image.FORMAT_RGBH, Image.FORMAT_RGBAH, Image.FORMAT_RGF]:
		return 8.0
	if fmt in [Image.FORMAT_RGBF, Image.FORMAT_RGBAF]:
		return 16.0

	return 4.0


func is_active() -> bool:
	return _active


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if not _active or _letting_go or get_tree().auto_accept_quit:
		return
	if _close_held_frame < 0:
		_close_held_frame = Engine.get_process_frames()
		_close_held_msec = Time.get_ticks_msec()
		_close_note.text = tr("Still loading. Close the game again to quit.")
		_close_note.visible = true
		_tip.visible = false
		return
	if Engine.get_process_frames() - _close_held_frame < CLOSE_AGAIN_FRAMES or Time.get_ticks_msec() - _close_held_msec < CLOSE_AGAIN_MS:
		return


	_letting_go = true
	_let_close_through.call_deferred()


func _let_close_through() -> void:
	get_tree().auto_accept_quit = true
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()


func is_covering() -> bool:
	return _root.visible and _root.modulate.a > 0.99


func cover_state() -> Dictionary:
	return { "visible": _root.visible, "alpha": _root.modulate.a, "active": _active }


func showing_tip() -> String:
	if not _tip.visible or _tip_out or _tip_alpha < 1.0:
		return ""
	return _tip.text


func step_tip(delta: float) -> void:
	if not _tip.visible:
		return
	if _tip_out:
		_tip_alpha = maxf(_tip_alpha - delta / TIP_FADE, 0.0)
		if _tip_alpha <= 0.0:
			_put_tip(GameTips.draw(_tip_bag, _tip_rng))
			_tip_out = false
	elif _tip_alpha < 1.0:
		_tip_alpha = minf(_tip_alpha + delta / TIP_FADE, 1.0)
	else:
		_tip_left -= delta
		if _tip_left <= 0.0:
			_tip_out = true
	_tip.modulate.a = _tip_alpha


static func tip_seconds(text: String) -> float:
	return clampf(TIP_READ_START + text.length() / TIP_CHARS_PER_SECOND,
		TIP_MIN_SECONDS, TIP_MAX_SECONDS)


func _put_tip(i: int) -> void:


	_tip.text = GameTips.say(i) if i >= 0 else ""
	_tip_left = tip_seconds(_tip.text)


func _process(delta: float) -> void:
	if not _active:
		return
	_spinner.queue_redraw()
	step_tip(delta)
	if is_equal_approx(_shown, _target):
		return


	_shown = move_toward(_shown, _target, maxf(delta * 0.9, (_target - _shown) * delta * 6.0))
	_apply_bar()


func _apply_bar() -> void:
	_bar_fill.offset_right = _bar_fill.offset_left + BAR_W * _shown
	_percent.text = Cfg.percent(str(int(round(_shown * 100.0))))


func _draw_spinner() -> void:
	var centre:= _spinner.size * 0.5
	var head:= float(Time.get_ticks_msec()) / 1000.0 * TAU * SPIN_TURNS_PER_SECOND
	_spinner.draw_arc(centre, SPIN_RADIUS, 0.0, TAU, 48, COL_BAR_BACK, SPIN_WIDTH, true)
	_spinner.draw_arc(centre, SPIN_RADIUS, head - PI * 0.4, head, 16,
		Color(COL_BAR, 0.35), SPIN_WIDTH, true)
	_spinner.draw_arc(centre, SPIN_RADIUS, head, head + PI * 0.6, 24,
		COL_BAR, SPIN_WIDTH, true)


func _on_pre_draw() -> void:
	if not _active:
		return
	var now:= Time.get_ticks_usec()
	_frame_script = (now - _mark_usec) / 1000.0
	_pre_draw_usec = now


func _on_post_draw() -> void:
	if not _active or _pre_draw_usec == 0:
		return
	var now:= Time.get_ticks_usec()
	var draw:= (now - _pre_draw_usec) / 1000.0
	var counts:= _pipeline_counts()
	var compiled:= counts - _compiles_seen
	_compiles_seen = counts
	var e: Dictionary = _steps.get(_body, { "frames": 0, "script": 0.0, "draw": 0.0,
		"worst": 0.0, "worst_script": 0.0, "worst_draw": 0.0,
		"at_draw": 0, "at_load": 0 })
	e ["frames"] += 1
	e ["script"] += _frame_script
	e ["draw"] += draw
	e ["at_draw"] += compiled.x
	e ["at_load"] += compiled.y
	if _frame_script + draw > e ["worst"]:
		e ["worst"] = _frame_script + draw
		e ["worst_script"] = _frame_script
		e ["worst_draw"] = draw
	_steps [_body] = e
	if _frame_script + draw >= SLOW_FRAME_MS:
		print("[load] slow frame in %s: %.0f ms script, %.0f ms draw, %d pipelines compiled while drawing, %d ahead"
			% [_body, _frame_script, draw, compiled.x, compiled.y])
	_mark_usec = now
	_pre_draw_usec = 0
	_body = _caption.text


func _print_timing() -> void:
	if _steps.is_empty():
		return
	print("[load] %-26s %6s %9s %9s %9s %9s   %s" % ["step", "frames", "script",
		"draw", "pl@draw", "pl ahead", "worst frame (script + draw), ms"])
	var total:= 0.0
	for step_name: String in _steps:
		var e: Dictionary = _steps [step_name]
		total += e ["script"] + e ["draw"]
		print("[load] %-26s %6d %9.0f %9.0f %9d %9d   %6.0f (%.0f + %.0f)" % [step_name,
			e ["frames"], e ["script"], e ["draw"], e ["at_draw"], e ["at_load"],
			e ["worst"], e ["worst_script"], e ["worst_draw"]])
	print("[load] total %.0f ms" % total)


func _pipeline_counts() -> Vector2i:
	return Vector2i(
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE)
		+ RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH)
		+ RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION))
