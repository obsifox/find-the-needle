class_name NeedleWallhack
extends Node3D


const BEAM_H:= 24.0
const BEAM_W:= 0.05


const PIP:= 0.14


const REFRESH:= 0.1

const COL_BURIED:= Color(1.0, 0.72, 0.18)
const COL_LOOSE:= Color(0.35, 0.95, 1.0)

var live: LiveStrandManager
var player: Node3D

var _enabled:= false


var _markers: Array [Dictionary] = []
var _since:= 0.0

var _beam_mesh: BoxMesh
var _pip_mesh: BoxMesh


var _tags:= true


func _ready() -> void:
	_tags = DisplayServer.get_name() != "headless"
	_beam_mesh = BoxMesh.new()
	_beam_mesh.size = Vector3(BEAM_W, BEAM_H, BEAM_W)
	_pip_mesh = BoxMesh.new()
	_pip_mesh.size = Vector3(PIP, PIP, PIP)
	visible = false
	set_process(false)


func is_enabled() -> bool:
	return _enabled


func toggle() -> bool:
	set_enabled(not _enabled)
	return _enabled


func set_enabled(on: bool) -> void:
	_enabled = on
	visible = on
	set_process(on)
	if on:
		_since = REFRESH
	else:
		for m in _markers:
			(m ["root"] as Node3D).visible = false


func census() -> Dictionary:
	var buried:= 0
	for i in GameState.needle_positions.size():
		if i < GameState.needle_taken.size() and GameState.needle_taken [i] == 0:
			buried += 1
	var loose:= 0
	if live != null:
		for b in live.needles:
			if is_instance_valid(b):
				loose += 1
	return { "buried": buried, "loose": loose }


func _process(delta: float) -> void:
	_since += delta
	var relabel:= _since >= REFRESH
	if relabel:
		_since = 0.0
	var here:= global_position
	if is_instance_valid(player):
		here = player.global_position

	var used:= 0


	for i in GameState.needle_positions.size():
		if i >= GameState.needle_taken.size() or GameState.needle_taken [i] != 0:
			continue
		var p:= GameState.needle_positions [i]
		var type:= int(GameState.needle_type [i]) if i < GameState.needle_type.size() else -1
		_place(used, p, COL_BURIED, relabel,
			"BURIED  %.0f m" % p.distance_to(here), _name_of(type))
		used += 1
	if live != null:
		for b in live.needles:
			if not is_instance_valid(b):
				continue
			var p:= b.global_position


			var what:= "PINNED" if LiveStrandManager.is_pinned(b) else ("HELD" if b.freeze else "LOOSE")
			_place(used, p, COL_LOOSE, relabel,
				"%s  %.0f m" % [what, p.distance_to(here)],
				_name_of(int(b.get_meta("needle_type", -1))))
			used += 1

	for k in range(used, _markers.size()):
		(_markers [k] ["root"] as Node3D).visible = false


func _name_of(type: int) -> String:
	if type < 0 or type >= NeedleTypes.count():
		return ""
	return NeedleTypes.name_of(type)


func _place(index: int, at: Vector3, colour: Color, relabel: bool,
		text: String, title: String) -> void:
	while _markers.size() <= index:
		_markers.append(_make_marker())
	var m:= _markers [index]
	var root:= m ["root"] as Node3D
	root.visible = true
	root.global_position = at
	var beam:= m ["beam"] as MeshInstance3D
	var pip:= m ["pip"] as MeshInstance3D
	var tag:= m ["tag"] as Label3D
	var name_tag:= m ["name"] as Label3D


	if Color(m.get("colour", Color.BLACK)) != colour:
		m ["colour"] = colour
		(beam.material_override as StandardMaterial3D).albedo_color = Color(colour, 0.3)
		(pip.material_override as StandardMaterial3D).albedo_color = colour
		if tag != null:
			tag.modulate = colour
			name_tag.modulate = colour
	if relabel and tag != null:
		tag.text = text
		name_tag.text = title


func _make_marker() -> Dictionary:
	var root:= Node3D.new()


	root.top_level = true
	add_child(root)

	var beam:= MeshInstance3D.new()
	beam.mesh = _beam_mesh
	beam.position = Vector3(0, BEAM_H * 0.5, 0)
	beam.material_override = _marker_material(0.3)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)

	var pip:= MeshInstance3D.new()
	pip.mesh = _pip_mesh
	pip.material_override = _marker_material(1.0)
	pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pip)

	if not _tags:
		return { "root": root, "beam": beam, "pip": pip, "tag": null,
			"name": null, "colour": Color.BLACK }

	var tag:= _make_label(48, 10)


	tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	root.add_child(tag)

	var name_tag:= _make_label(36, 8)
	name_tag.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	root.add_child(name_tag)

	return { "root": root, "beam": beam, "pip": pip, "tag": tag,
		"name": name_tag, "colour": Color.BLACK }


func _make_label(font_size: int, outline: int) -> Label3D:
	var label:= Label3D.new()
	label.position = Vector3(0, 0.32, 0)
	label.font_size = font_size
	label.pixel_size = 0.0005


	label.fixed_size = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.outline_size = outline
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.render_priority = 100
	label.outline_render_priority = 99
	return label


func _marker_material(alpha: float) -> StandardMaterial3D:
	var m:= StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.disable_receive_shadows = true
	m.albedo_color = Color(COL_LOOSE, alpha)
	m.render_priority = 98
	return m
