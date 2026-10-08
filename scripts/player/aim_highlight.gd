class_name AimHighlight
extends Node3D


const MARGIN:= 0.0045


const REFRESH:= 0.04

var player: Player
var field: HayField

var _mi: MeshInstance3D

var _body: RigidBody3D = null
var _since:= 0.0

var _scoop_lit:= false


var _marked: NeedleCabinet = null
var _marked_type:= -1

var _marked_action:= ""


var _lit_button: NeedleCabinet = null

var _hay_aimed:= false


func _ready() -> void:
	_mi = MeshInstance3D.new()
	_mi.name = "Outline"

	_mi.top_level = true
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.material_override = _outline_material()
	_mi.visible = false
	add_child(_mi)


static func _outline_material() -> StandardMaterial3D:
	var m:= StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1)


	m.cull_mode = BaseMaterial3D.CULL_FRONT
	return m


func has_target() -> bool:
	return _scoop_lit or _marked != null or (_mi != null and _mi.visible)


func strand_lit() -> bool:
	return _mi != null and _mi.visible


func needle_lit() -> bool:
	return strand_lit() and is_instance_valid(_body) and _body.has_meta("needle_index")


func hay_aimed() -> bool:
	return _hay_aimed and _should_run()


func scoop_lit() -> bool:
	return _scoop_lit


func _process(delta: float) -> void:
	_since += delta
	if player == null or field == null:
		_clear()
		_clear_scoop()
		_clear_marker()
		return

	if player.current_tool == Player.Tool.SHOVEL or player.current_tool == Player.Tool.PITCHFORK or player.current_tool == Player.Tool.YARD_VAC or player.current_tool == Player.Tool.LIGHTER or (player.carry.is_carrying() and player.carry.held() is SandShovel):

		_clear()
		_clear_marker()
		if _since >= REFRESH:
			_since = 0.0
			_update_scoop()
		return

	_clear_scoop()


	if _update_deposit():
		_clear()
		return
	if not _should_run():
		_clear()
		return
	if _since >= REFRESH:
		_since = 0.0
		_query()
	elif is_instance_valid(_body):


		if player.hand.holds(_body) or not _body.is_inside_tree():
			_clear()
		else:
			_track_body()


func _update_scoop() -> void:
	var aim: Dictionary
	if player.carry.is_carrying() and player.carry.held() is SandShovel:
		aim = (player.carry.held() as SandShovel).aim_point()
	elif player.current_tool == Player.Tool.PITCHFORK:
		aim = player.pitchfork.aim_point()
	elif player.current_tool == Player.Tool.YARD_VAC:
		aim = player.yard_vac.aim_point()
	elif player.current_tool == Player.Tool.LIGHTER:


		aim = player.lighter.aim_point()
	else:
		aim = player.shovel.aim_point()
	if aim.is_empty():
		_clear_scoop()
		return
	_scoop_lit = true
	var radius:= Cfg.SCOOP_RADIUS
	if player.carry.is_carrying() and player.carry.held() is SandShovel:
		radius = SandShovel.SCOOP_RADIUS
	elif player.current_tool == Player.Tool.PITCHFORK:
		radius = Pitchfork.SCOOP_RADIUS


	if aim.has("radius"):
		StrandFactory.set_highlight(aim ["position"], float(aim ["radius"]))
		return


	if bool(aim.get("loose", false)):
		radius *= Shovel.GATHER_REACH
	StrandFactory.set_highlight(aim ["position"], radius)


func _clear_scoop() -> void:
	if not _scoop_lit:
		return
	_scoop_lit = false
	StrandFactory.set_highlight(Vector3.ZERO, 0.0)


func _exit_tree() -> void:
	_clear_scoop()


	if is_instance_valid(_lit_button):
		_lit_button.highlight_ending(false)
	_lit_button = null


func _update_button() -> bool:
	var cab: NeedleCabinet = null
	if player.current_tool == Player.Tool.HAND and player.hand != null and not player.carry.is_carrying():
		cab = player.hand.ending_target()
	if cab != _lit_button:


		if is_instance_valid(_lit_button):
			_lit_button.highlight_ending(false)
		_lit_button = cab
	if cab == null:
		return false
	cab.highlight_ending(true)
	_marked_action = "press"
	return true


func _update_deposit() -> bool:
	if _update_button():
		return true
	var cab: NeedleCabinet = null
	var type:= -1
	if player.current_tool == Player.Tool.HAND and player.hand != null and not player.carry.is_carrying():
		cab = player.hand.deposit_target()
		if cab != null:
			type = GameState.type_of(player.hand.held_needle_index())
			_marked_action = "deposit"
		else:


			var out:= player.hand.case_target()
			if not out.is_empty():
				cab = out ["cabinet"]
				type = out ["type"]
				_marked_action = String(out ["action"])
	if cab != _marked:
		_clear_marker()
	if cab == null or type < 0:
		_marked = null
		_marked_action = ""
		return false
	_marked = cab
	_marked_type = type
	cab.show_slot_marker(type)
	return true


func marked_type() -> int:
	return _marked_type if _marked != null else -1


func marked_action() -> String:
	return _marked_action if _marked != null else ""


func _clear_marker() -> void:
	if is_instance_valid(_marked):
		_marked.hide_slot_marker()
	_marked = null
	_marked_type = -1
	_marked_action = ""


func _should_run() -> bool:
	return (player != null and field != null
		and player.current_tool == Player.Tool.HAND
		and not player.hand.is_holding_needle()


		and not player.carry.is_carrying())


func _query() -> void:


	var hit:= player.hand.aim_hit()
	_hay_aimed = player.hand.is_hay_hit(hit)


	if not _hay_aimed or player.hand.is_full():
		_clear()
		return
	var from:= player.eye_position()
	var dir:= player.look_direction()

	var collider: Object = hit.get("collider")
	if collider is RigidBody3D and (collider as RigidBody3D).collision_layer & HandTool.HAY_LAYERS:
		_body = collider as RigidBody3D
		_track_body()
		return


	_body = null
	var found:= field.peek_at(hit ["position"], 0.45, from, dir)
	if found.is_empty():
		found = field.peek_at(hit ["position"] + Vector3(0, 0.06, 0), 0.7, from, dir)
	if found.is_empty():
		_clear()
		return
	_show(found ["transform"], StrandFactory.strand_outline_mesh())


func _track_body() -> void:


	var m: Mesh = (StrandFactory.needle_mesh(int(_body.get_meta("needle_type", 0)))
		if _body.has_meta("needle_index") else StrandFactory.strand_outline_mesh())


	var xf:= _body.get_global_transform_interpolated()


	xf.basis.z *= float(_body.get_meta(LiveStrandManager.META_LEN, 1.0))
	_show(xf, m)


func _show(xf: Transform3D, mesh: Mesh) -> void:
	if _mi.mesh != mesh:
		_mi.mesh = mesh
	var s:= mesh.get_aabb().size


	var len_scale:= xf.basis.z.length()


	var sc:= Vector3(
		1.0 + 2.0 * minf(MARGIN, s.x * 1.2) / s.x,
		1.0 + 2.0 * minf(MARGIN, s.y * 1.2) / s.y,
		1.0 + 2.0 * minf(MARGIN, s.z * 1.2) / s.z)
	sc.z *= len_scale
	_mi.global_transform = xf.orthonormalized().scaled_local(sc)
	_mi.visible = true


func _clear() -> void:
	_body = null
	if _mi != null:
		_mi.visible = false
