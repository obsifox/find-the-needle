class_name DroneZoneMode
extends Node3D


const AIM_DIST:= 45.0
const COL_OK:= Color(1.0, 1.0, 1.0, 0.85)
const COL_OUT:= Color(1.0, 0.24, 0.18, 0.95)

var player: Player

var hint_layer: CanvasLayer

var _drone: HayDrone
var _active:= false

var _r:= 3.0
var _hover:= Vector3.INF


var _hover_top:= Vector3.INF
var _hover_kind: int = HayDrone.Drop.NONE

var _zone_why:= ""
var _drop_why:= ""

var _note:= ""
var _note_left:= 0.0
var _drawn_key:= ""
var _ghost: MeshInstance3D
var _tag: Label3D
var _hint: Control
var _hint_sub: Label


var _taken: Node3D
var _taken_left:= 0.0
static var _mats: Dictionary = { }


func _ready() -> void:
	set_process(false)
	_ghost = MeshInstance3D.new()
	_ghost.name = "ZoneGhost"
	_ghost.top_level = true
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	_tag = Label3D.new()
	_tag.font = UiFont.bold()


	_tag.fixed_size = true
	_tag.font_size = 40
	_tag.pixel_size = 0.0011
	_tag.outline_size = 10
	_tag.outline_modulate = Color(0.03, 0.04, 0.06, 0.9)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.top_level = true
	_tag.visible = false
	add_child(_tag)
	_taken = Node3D.new()
	_taken.name = "TakenMarks"
	_taken.top_level = true
	add_child(_taken)
	_hint = _build_hint()
	_hint.visible = false
	if hint_layer != null:
		hint_layer.add_child(_hint)
	else:
		add_child(_hint)


func is_active() -> bool:
	return _active


func is_open() -> bool:
	return _active


func drone() -> HayDrone:
	return _drone if _active else null


func begin(target: HayDrone) -> void:
	if target == null or not is_instance_valid(target):
		return
	if _active:
		end()
	_drone = target
	_active = true
	_r = clampf(target.zone_r, HayDrone.ZONE_MIN, target.zone_max())
	_hover = Vector3.INF
	_drawn_key = ""
	_note = ""
	_drone.show_job(true)
	_drone.show_range(true)
	_taken_left = 0.0
	_hint.visible = true
	set_process(true)
	if player != null:
		player.capture_mouse(true)


func end() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	_ghost.visible = false
	_tag.visible = false
	_hint.visible = false
	_clear_taken()
	var was:= _drone
	_drone = null
	if was != null and is_instance_valid(was):
		was.show_range(false)
		if was.job_seconds_left() <= 0.0:
			was.show_job(false)


func handle(event: InputEvent) -> bool:
	if not _active:
		return false
	var wheel:= event as InputEventMouseButton
	if wheel != null and wheel.pressed and (wheel.button_index == MOUSE_BUTTON_WHEEL_UP
			or wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_resize(HayDrone.ZONE_STEP if wheel.button_index == MOUSE_BUTTON_WHEEL_UP
			else - HayDrone.ZONE_STEP)
		return true
	if event.is_action_pressed("primary"):
		_click_zone()
		return true
	if event.is_action_pressed("secondary"):
		_click_drop()
		return true
	if event.is_action_pressed("interact") or event.is_action_pressed("free_mouse"):
		end()
		return true
	return false


func _resize(by: float) -> void:
	if not is_instance_valid(_drone):
		return
	var was:= _r
	_r = clampf(_r + by, HayDrone.ZONE_MIN, _drone.zone_max())
	if is_equal_approx(was, _r):
		Audio.play("ui_error")
		_say(tr("That is as big as it goes. Longer Range makes zones bigger.")
			if by > 0.0 else tr("That is as small as it goes."))
		return
	if _drone.zone_at != Vector3.INF:
		var why:= _drone.set_zone(_drone.zone_at, _r)
		if why != "":
			_r = was
			Audio.play("ui_error")
			_say(why)
			return
		_after_change()
	Audio.play("ui_click")
	_drawn_key = ""


func _click_zone() -> void:
	if not is_instance_valid(_drone):
		end()
		return
	if _hover == Vector3.INF:
		return
	if _zone_why != "":
		Audio.play("ui_error")
		_say(_zone_why)
		return
	var why:= _drone.set_zone(_hover, _r)
	if why != "":
		Audio.play("ui_error")
		_say(why)
		return
	Audio.play("ui_click")
	_after_change()


func _click_drop() -> void:
	if not is_instance_valid(_drone):
		end()
		return
	if _hover == Vector3.INF or _hover_kind == HayDrone.Drop.NONE:
		Audio.play("ui_error")
		_say(tr("A drop goes on a belt, on hay stairs or on the floor."))
		return
	if _drop_why != "":
		Audio.play("ui_error")
		_say(_drop_why)
		return
	var why:= _drone.set_drop(_hover, _hover_kind)
	if why != "":
		Audio.play("ui_error")
		_say(why)
		return
	Audio.play("ui_click")
	_after_change()


func _after_change() -> void:
	_drawn_key = ""
	if not _drone.has_job():
		_say(tr("Now set the drop.") if _drone.drop_at == Vector3.INF
			else tr("Now set the zone."))
		return
	var why:= _drone.plan_now()
	if why != "":
		_say(why)
	else:
		_say(tr("Ready. It starts on its next look for work."))


func _say(text: String) -> void:
	_note = text
	_note_left = 3.0


func _process(delta: float) -> void:
	if not is_instance_valid(_drone) or not _drone.is_inside_tree():
		end()
		return
	if player == null:
		return


	var away:= player.global_position - _drone.global_position
	if Vector2(away.x, away.z).length() > _drone.radius() + 20.0:
		end()
		return
	if _note_left > 0.0:
		_note_left -= delta
	_taken_left -= delta
	if _taken_left <= 0.0:
		_taken_left = 2.0
		_draw_taken()
	_aim()
	_draw()
	_write_hint()


func _draw_taken() -> void:
	_clear_taken()
	_taken.global_transform = Transform3D.IDENTITY
	for mark in HayDrone.taken_marks(_drone):
		_taken.add_child(mark)


func _clear_taken() -> void:
	for kid in _taken.get_children():
		kid.queue_free()


func _aim() -> void:
	_hover = Vector3.INF
	_hover_kind = HayDrone.Drop.NONE
	_zone_why = ""
	_drop_why = ""
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * AIM_DIST)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var at: Vector3 = hit ["position"]
	var normal: Vector3 = hit ["normal"]
	var collider:= hit.get("collider") as Node
	_hover_top = at


	var body:= collider as CollisionObject3D
	var on_pile:= body != null and (body.collision_layer & Cfg.L_PILE) != 0
	var run:= ArmLinkMode._belt_of(collider)
	if RoboticArm.linkable(run):
		_hover = run._point_at(run.s_at(at))
		_hover_kind = HayDrone.Drop.BELT
	else:
		var owner:= _drone.builds.owner_of(collider) if _drone.builds != null else null
		if owner is HayStairs:
			_hover = (owner as HayStairs).mouth_position()
			_hover_kind = HayDrone.Drop.STAIRS
		elif _in_stand(collider):
			_hover = at
			_drop_why = tr("NOT THE SELLING STAND")
		elif on_pile:

			_hover = Vector3(at.x, 0.0, at.z)
			_drop_why = tr("NOT ON THE PILE")
		elif normal.y > 0.6 and (owner == null or owner is Platform):
			_hover = at
			_hover_kind = HayDrone.Drop.FLOOR
		elif normal.y > 0.3:
			_hover = Vector3(at.x, 0.0, at.z) if on_pile else at
			_drop_why = tr("NOT HERE")
		else:
			return
	if _drop_why == "" and _hover_kind != HayDrone.Drop.NONE:
		_drop_why = _drone.drop_refusal(_hover)
	_zone_why = _drone.zone_refusal(_hover, _r) if normal.y > 0.3 else tr("NOT HERE")


static func _in_stand(node: Node) -> bool:
	var n:= node
	for _i in 8:
		if n == null:
			return false
		if n is HaySellingStand:
			return true
		n = n.get_parent()
	return false


func _draw() -> void:
	if _hover == Vector3.INF:
		_ghost.visible = false
		_tag.visible = false
		return
	var snapped:= _hover.snapped(Vector3.ONE * 0.1)
	var key:= "%s %.2f %s %s" % [snapped, _r, _zone_why, _drop_why]
	if key != _drawn_key:
		_drawn_key = key
		var ok:= _zone_why == ""
		_ghost.mesh = _ring(snapped, _r)
		_ghost.material_override = _mat(COL_OK if ok else COL_OUT)
	_ghost.visible = true
	var lines: Array [String] = []
	if _zone_why != "":
		lines.append(_zone_why)
	elif _drone.mode == HayDrone.Mode.DIG:
		lines.append(tr("DIG ZONE  ·  %.1f m") % _r)
	else:
		lines.append(tr("COLLECT ZONE  ·  %.1f m") % _r)
	_tag.text = "\n".join(lines)
	_tag.modulate = COL_OK if _zone_why == "" else COL_OUT
	_tag.global_position = _hover_top + Vector3.UP * 1.2
	_tag.visible = true


func _ring(at: Vector3, r: float) -> ArrayMesh:
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs:= 64
	var field:= _drone.field
	var pts: Array [Vector3] = []
	for i in segs + 1:
		var a:= TAU * float(i) / float(segs)
		var c:= Vector3(at.x + cos(a) * r, 0.0, at.z + sin(a) * r)
		var h:= field.height_at(c.x, c.z) if field != null else - INF
		c.y = maxf(h, at.y) + 0.08
		pts.append(c)
	for i in segs:
		RoboticArm._ribbon(st, pts [i], pts [i + 1], Vector3.UP, 0.12)
	return st.commit()


func _mat(colour: Color) -> StandardMaterial3D:
	var key:= colour.to_html()
	if not _mats.has(key):
		var m:= HayDrone._new_ring_mat(colour)
		m.no_depth_test = true
		m.render_priority = 2
		_mats [key] = m
	return _mats [key]


func _build_hint() -> Control:
	var bar:= HBoxContainer.new()
	bar.name = "DroneZoneHint"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = Hud.PROMPT_TOP
	bar.offset_bottom = Hud.PROMPT_TOP + Hud.PROMPT_HEIGHT
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	var plate:= PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.72)
	sb.border_color = Color(1.0, 0.86, 0.34, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 9.0
	plate.add_theme_stylebox_override("panel", sb)
	bar.add_child(plate)
	var col:= VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	plate.add_child(col)
	var row:= HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_key_pair(row, InputSetup.spec_of("primary"), InputSetup.hint("primary"), tr("ZONE"),
		RoboticArm.COL_TAKE)
	_key_pair(row, "wheel", tr("WHEEL"), tr("SIZE"), Hud.COL_PROMPT_TITLE)
	_key_pair(row, InputSetup.spec_of("secondary"), InputSetup.hint("secondary"), tr("DROP"),
		RoboticArm.COL_PUT)
	_key_pair(row, InputSetup.spec_of("interact"), InputSetup.hint("interact"), tr("DONE"),
		Hud.COL_PROMPT_TITLE)
	_hint_sub = Label.new()
	UiFont.style(_hint_sub, 14, Hud.COL_PROMPT_SUB, 4)
	col.add_child(_hint_sub)
	return bar


func _key_pair(row: HBoxContainer, spec: String, key_text: String, word: String,
		colour: Color) -> void:
	row.add_child(InputIcons.prompt_cap(spec, key_text, 34.0))
	var label:= Label.new()
	label.text = word
	UiFont.style(label, 20, colour, 4, true)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var gap:= Control.new()
	gap.custom_minimum_size.x = 8.0
	row.add_child(gap)


func _write_hint() -> void:
	if _note_left > 0.0 and _note != "":
		_hint_sub.text = _note
		return
	if _hover == Vector3.INF:
		_hint_sub.text = tr("Look at the pile, the floor or a belt inside the ring.")
		return
	var drop:= ""
	match _hover_kind:
		HayDrone.Drop.BELT:
			drop = tr("It can drop on this belt.")
		HayDrone.Drop.STAIRS:
			drop = tr("It can drop into these hay stairs.")
		HayDrone.Drop.FLOOR:
			drop = tr("It can drop on the floor here.")
	if _drop_why != "":
		drop = tr("No drop here: %s.") % _drop_why
	var zone:= tr("Its zone can go here.") if _zone_why == "" else tr("No zone here: %s.") % _zone_why
	_hint_sub.text = "%s  %s" % [zone, drop]
