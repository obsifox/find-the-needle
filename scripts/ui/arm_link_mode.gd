class_name ArmLinkMode
extends Node3D


const AIM_DIST:= 14.0

const EDGE_OUT:= 0.05
const EDGE_LIFT:= 0.06
const EDGE_SOLID:= 0.055
const DASH_ON:= 0.22
const DASH_OFF:= 0.14


const LEAVE_DIST:= 10.0

const COL_REACH:= Color(0.42, 0.78, 0.48, 0.2)
const COL_SOLID:= Color(1.0, 1.0, 1.0, 0.95)
const COL_OUT:= Color(1.0, 0.24, 0.18, 0.95)


enum { REFUSE_NONE, REFUSE_SPLITTER, REFUSE_JOINER, REFUSE_ENCLOSED }

var player: Player

var hint_layer: CanvasLayer

var _arm: RoboticArm
var _active:= false


var _hover: BeltPath
var _hover_at:= Vector3.ZERO
var _hover_ok:= false


var _refused:= REFUSE_NONE
var _refused_at:= Vector3.ZERO
var _refused_run: BeltPath

var _drawn_key:= ""
var _edges: MeshInstance3D
var _out_tag: Label3D
var _hint: Control
var _hint_sub: Label
var _mats: Dictionary = { }


func _ready() -> void:
	set_process(false)
	_edges = MeshInstance3D.new()
	_edges.name = "LinkEdges"
	_edges.top_level = true
	_edges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_edges.visible = false
	add_child(_edges)
	_out_tag = Label3D.new()
	_out_tag.text = tr("OUT OF REACH")
	_out_tag.font = UiFont.bold()
	_out_tag.font_size = 44
	_out_tag.pixel_size = 0.004
	_out_tag.outline_size = 10
	_out_tag.modulate = COL_OUT
	_out_tag.outline_modulate = Color(0.03, 0.04, 0.06, 0.9)
	_out_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_out_tag.no_depth_test = true
	_out_tag.top_level = true
	_out_tag.visible = false
	add_child(_out_tag)
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


func arm() -> RoboticArm:
	return _arm if _active else null


func begin(target: RoboticArm) -> void:
	if target == null or not is_instance_valid(target):
		return
	if _active:
		end(false)
	_arm = target
	_active = true
	_hover = null
	_drawn_key = ""
	_arm.set_choosing(true)
	_hint.visible = true
	set_process(true)
	if player != null:
		player.capture_mouse(true)


func end(reopen: bool) -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	_edges.visible = false
	_out_tag.visible = false
	_hint.visible = false
	var was:= _arm
	_arm = null
	_hover = null
	_refused = REFUSE_NONE
	_refused_run = null
	if was != null and is_instance_valid(was):
		was.set_choosing(false)
		if reopen and player != null and player.arm_panel != null:
			player.arm_panel.call_deferred("open", was)


func handle(event: InputEvent) -> bool:
	if not _active:
		return false
	if event.is_action_pressed("primary"):
		_click(RoboticArm.LINK_TAKE)
		return true
	if event.is_action_pressed("secondary"):
		_click(RoboticArm.LINK_PUT)
		return true
	if event.is_action_pressed("interact"):
		end(true)
		return true
	if event.is_action_pressed("free_mouse"):
		end(false)
		return true
	return false


func _click(role: int) -> void:
	if not is_instance_valid(_arm):
		end(false)
		return
	if _hover == null:
		if _refused != REFUSE_NONE:
			Audio.play("ui_error")
		return
	if not _hover_ok:
		Audio.play("ui_error")
		return
	var before:= _arm.link_role(_hover)
	var after:= _arm.set_link(_hover, _hover_at, role)
	if after != before:
		Audio.play("ui_click")
	_drawn_key = ""


func _process(_delta: float) -> void:
	if not is_instance_valid(_arm) or not _arm.is_inside_tree():
		end(false)
		return
	if player == null:
		return

	var away:= player.global_position - _arm.global_position
	if Vector2(away.x, away.z).length() > LEAVE_DIST:
		end(false)
		return
	_aim()
	_write_hint()
	_draw()


func _aim() -> void:
	_hover = null
	_hover_ok = false
	_refused = REFUSE_NONE
	_refused_run = null
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * AIM_DIST)
	q.collision_mask = Cfg.L_BUILD
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var collider:= hit.get("collider") as Node
	var run:= _belt_of(collider)
	if not RoboticArm.linkable(run):
		_refused = _refusal(collider, run)
		if _refused != REFUSE_NONE:
			_refused_at = hit ["position"]
			if _refused == REFUSE_ENCLOSED:
				_refused_run = run
		return
	_hover = run
	_hover_at = run._point_at(run.s_at(hit ["position"] as Vector3))
	_hover_ok = _arm.link_in_reach(_hover_at)


static func _belt_of(node: Node) -> BeltPath:
	var n:= node
	for _i in 6:
		if n == null:
			return null
		if n is BeltPath:
			return n as BeltPath
		n = n.get_parent()
	return null


static func _refusal(collider: Node, run: BeltPath) -> int:
	if run is EnclosedConveyor or run is EnclosedConveyorCorner:
		return REFUSE_ENCLOSED
	var n:= collider
	for _i in 8:
		if n == null:
			break
		if n is ConveyorSplitter:
			return REFUSE_SPLITTER
		if n is ConveyorJoiner:
			return REFUSE_JOINER
		n = n.get_parent()
	return REFUSE_NONE


func _draw() -> void:
	var key:= "%d %s %d %d %d" % [_hover.get_instance_id() if _hover != null else 0,
		_hover_ok, _arm.links().size(), _refused,
		_refused_run.get_instance_id() if _refused_run != null else 0]
	if key == _drawn_key:
		return
	_drawn_key = key
	var mesh:= ArrayMesh.new()
	var reach: Array = []
	if _arm.builds != null:
		for pick in _arm.builds.conveyor_drops(_arm._shoulder_world(), _arm.work_reach()):
			var run:= pick.get("conveyor") as BeltPath
			if RoboticArm.linkable(run):
				reach.append(run)
	var strip:= RoboticArm.reach_strip(reach, _arm._shoulder_world(), _arm.work_reach())
	if not strip.is_empty():
		var st:= SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in strip:
			st.add_vertex(v)

		st.set_material(_mat(COL_REACH, 1))
		st.commit(mesh)
	if _hover != null:
		if _hover_ok:
			_edge_surface(mesh, _hover, COL_SOLID, EDGE_SOLID, false)
		else:
			_edge_surface(mesh, _hover, COL_OUT, EDGE_SOLID, true)
	elif _refused_run != null:
		_edge_surface(mesh, _refused_run, COL_OUT, EDGE_SOLID, true)
	_edges.mesh = mesh
	_edges.visible = mesh.get_surface_count() > 0
	var tag:= ""
	var tag_at:= Vector3.ZERO
	if _hover != null and not _hover_ok:
		tag = tr("OUT OF REACH")
		tag_at = _hover_at
	elif _hover == null and _refused != REFUSE_NONE:
		tag = tr("CAN'T LINK")
		tag_at = _refused_at
	_out_tag.visible = tag != ""
	if _out_tag.visible:

		if _out_tag.text != tag:
			_out_tag.text = tag
		_out_tag.global_position = tag_at + Vector3.UP * 0.8


func _edge_surface(mesh: ArrayMesh, run: BeltPath, colour: Color, width: float,
		dashed: bool) -> void:
	var line:= run.centre_line()
	if line.size() < 2:
		return
	var st:= SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half:= Cfg.BELT_WIDTH * 0.5 + EDGE_OUT
	for i in line.size() - 1:
		var a:= line [i]
		var b:= line [i + 1]
		if a.distance_squared_to(b) < 1e-06:
			continue
		var basis:= run.basis_at(run.s_at((a + b) * 0.5))
		for sign: float in [-1.0, 1.0]:
			var off:= basis.x * half * sign + basis.y * EDGE_LIFT
			if not dashed:
				RoboticArm._ribbon(st, a + off, b + off, basis.y, width)
				continue
			var span:= a.distance_to(b)
			var t:= 0.0
			while t < span:
				var t1:= minf(t + DASH_ON, span)
				RoboticArm._ribbon(st, a.lerp(b, t / span) + off, a.lerp(b, t1 / span) + off,
					basis.y, width)
				t = t1 + DASH_OFF
	st.set_material(_mat(colour))
	st.commit(mesh)


func _mat(colour: Color, priority:= 2) -> StandardMaterial3D:
	var key:= "%s %d" % [colour.to_html(), priority]
	if not _mats.has(key):
		var m:= HayDrone._new_ring_mat(colour)
		m.no_depth_test = true
		m.render_priority = priority
		_mats [key] = m
	return _mats [key]


func _build_hint() -> Control:
	var bar:= HBoxContainer.new()
	bar.name = "ChooseBeltsHint"
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
	_key_pair(row, "primary", tr("TAKE FROM"), RoboticArm.COL_TAKE)
	_key_pair(row, "secondary", tr("PUT ON"), RoboticArm.COL_PUT)
	_key_pair(row, "interact", tr("DONE"), Hud.COL_PROMPT_TITLE)
	_hint_sub = Label.new()
	UiFont.style(_hint_sub, 14, Hud.COL_PROMPT_SUB, 4)
	col.add_child(_hint_sub)
	return bar


func _key_pair(row: HBoxContainer, action: String, word: String, colour: Color) -> void:
	row.add_child(InputIcons.prompt_cap(InputSetup.spec_of(action),
		InputSetup.hint(action), 34.0))
	var label:= Label.new()
	label.text = word
	UiFont.style(label, 20, colour, 4, true)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var gap:= Control.new()
	gap.custom_minimum_size.x = 8.0
	row.add_child(gap)


func _write_hint() -> void:
	if _hover == null:
		match _refused:
			REFUSE_SPLITTER:
				_hint_sub.text = tr("Arms cannot link a splitter. Link the belt going in or out of it.")
			REFUSE_JOINER:
				_hint_sub.text = tr("Arms cannot link a joiner. Link the belt going in or out of it.")
			REFUSE_ENCLOSED:
				_hint_sub.text = tr("This belt is enclosed, so the arm cannot reach inside it.")
			_:
				_hint_sub.text = tr("Look at a belt near the arm.")
	elif not _hover_ok:
		_hint_sub.text = tr("Out of reach. The arm cannot get to this belt.")
	else:
		match _arm.link_role(_hover):
			RoboticArm.LINK_TAKE:
				_hint_sub.text = tr("It takes from this belt. Click again to unlink.")
			RoboticArm.LINK_PUT:
				_hint_sub.text = tr("It puts on this belt. Click again to unlink.")
			_:
				_hint_sub.text = tr("In reach. Click to link this belt.")
