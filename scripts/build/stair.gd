class_name Stair
extends StaticBody3D


var placement_preview:= false


static var _keep_empty_mm:= "--keepemptymm" in OS.get_cmdline_user_args()

var rise:= 2.0

var pitch:= Cfg.STAIR_PITCH


var paid_cost:= -1.0
var _steps:= 1
var _riser:= Cfg.STAIR_RISER
var _going:= Cfg.STAIR_RISER / Cfg.STAIR_PITCH

var _treads: MultiMeshInstance3D
var _stringers: Node3D
var _handrails: Node3D
var _collision: CollisionShape3D
var _shape: BoxShape3D
var _built_rise:= NAN
var _built_pitch:= NAN
var _preview_valid:= true


static func run_for(flight_rise: float,
		flight_pitch: float = Cfg.STAIR_PITCH) -> float:
	return flight_rise / clampf(flight_pitch, Cfg.STAIR_PITCH_MIN,
		Cfg.STAIR_PITCH_MAX)


static func cost_for(flight_rise: float,
		flight_pitch: float = Cfg.STAIR_PITCH) -> float:
	var run:= run_for(flight_rise, flight_pitch)
	var length:= sqrt(run * run + flight_rise * flight_rise)
	return length * Cfg.STAIR_COST_PER_M * Tech.build_cost_scale()


func build_cost() -> float:
	if paid_cost >= 0.0:
		return paid_cost
	return cost_for(rise, pitch)


func setup(head: Vector3, yaw: float, flight_rise: float,
		flight_pitch: float = Cfg.STAIR_PITCH) -> void:
	position = head
	rotation.y = yaw
	rise = clampf(flight_rise, Cfg.STAIR_RISER, Cfg.STAIR_MAX_RISE)
	pitch = clampf(flight_pitch, Cfg.STAIR_PITCH_MIN, Cfg.STAIR_PITCH_MAX)


	paid_cost = cost_for(rise, pitch)


func _ready() -> void:
	collision_layer = 0 if placement_preview else Cfg.L_BUILD
	collision_mask = 0
	_build_model()
	if placement_preview:
		set_preview_valid(true)


func set_shape(head: Vector3, yaw: float, flight_rise: float,
		flight_pitch: float = Cfg.STAIR_PITCH) -> void:
	var next:= clampf(flight_rise, Cfg.STAIR_RISER, Cfg.STAIR_MAX_RISE)
	var next_pitch:= clampf(flight_pitch, Cfg.STAIR_PITCH_MIN,
		Cfg.STAIR_PITCH_MAX)
	var moved:= not position.is_equal_approx(head) or not is_equal_approx(rotation.y, yaw)
	var resized:= not is_equal_approx(next, rise) or not is_equal_approx(next_pitch, pitch)
	if not moved and not resized:
		return
	position = head
	rotation.y = yaw
	rise = next
	pitch = next_pitch
	if resized:
		_build_model()
		if placement_preview:
			set_preview_valid(_preview_valid)


func foot() -> Vector3:
	return global_position + _descent() * run_for(rise, pitch) - Vector3(0.0, rise, 0.0)


func _descent() -> Vector3:
	return - global_transform.basis.z


func _build_model() -> void:
	if is_equal_approx(_built_rise, rise) and is_equal_approx(_built_pitch, pitch) and _treads != null:
		return
	_built_rise = rise
	_built_pitch = pitch


	_steps = maxi(1, int(ceil(rise / Cfg.STAIR_RISER)))
	_riser = rise / float(_steps)
	_going = _riser / pitch


	var stretch:= Basis().scaled(
		Vector3(1.0, 1.0, _going / StructureKit.TREAD_GOING))
	var treads: Array [Transform3D] = []


	for i in _steps - 1:


		treads.append(Transform3D(stretch, Vector3(
			0.0, - _riser * (i + 1), - _going * (i + 0.5))))
	if _treads != null:
		remove_child(_treads)
		_treads.queue_free()
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = StructureKit.tread_mesh()
	mm.instance_count = treads.size()
	for i in treads.size():
		mm.set_instance_transform(i, treads [i])
	_treads = MultiMeshInstance3D.new()
	_treads.name = "Treads"
	_treads.multimesh = mm


	_treads.visible = _keep_empty_mm or not treads.is_empty()
	if placement_preview:
		_treads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_treads)

	_build_stringers()
	_build_handrails()
	if not placement_preview:
		_build_collider()


func _build_stringers() -> void:
	if _stringers != null:
		remove_child(_stringers)
		_stringers.queue_free()
	_stringers = Node3D.new()
	_stringers.name = "Stringers"
	add_child(_stringers)
	var run:= run_for(rise, pitch)
	var slope:= sqrt(run * run + rise * rise)


	var tilt:= Basis(Vector3.RIGHT, - atan2(rise, run))
	var mid:= Vector3(0.0, - rise * 0.5, - run * 0.5)
	for side: float in [-1.0, 1.0]:
		var mi:= MeshInstance3D.new()
		mi.mesh = StructureKit.stringer_mesh()
		mi.transform = Transform3D(
			tilt.scaled_local(Vector3(1.0, 1.0, slope)),
			mid + Vector3(Cfg.STAIR_WIDTH * 0.5 * side, 0.0, 0.0))
		if placement_preview:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_stringers.add_child(mi)


func _build_handrails() -> void:
	if _handrails != null:
		remove_child(_handrails)
		_handrails.queue_free()
	for child in find_children("HandrailCollision*", "CollisionShape3D", false, false):
		remove_child(child)
		child.queue_free()
	_handrails = Node3D.new()
	_handrails.name = "Handrails"
	add_child(_handrails)

	var run:= run_for(rise, pitch)
	var slope:= sqrt(run * run + rise * rise)
	var tilt:= Basis(Vector3.RIGHT, - atan2(rise, run))
	var half:= Cfg.STAIR_WIDTH * 0.5
	var n:= maxi(1, int(ceil(slope / Cfg.PLATFORM_RAIL_POST_SPACING)))

	var posts: Array [Transform3D] = []
	var rails: Array [Transform3D] = []
	for side: float in [-1.0, 1.0]:
		for i in n + 1:
			var t:= float(i) / float(n)
			posts.append(Transform3D(Basis(), Vector3(
				half * side, - rise * t, - run * t)))
		rails.append(Transform3D(
			tilt.scaled_local(Vector3(1.0, 1.0, slope)),
			Vector3(half * side,
				- rise * 0.5 + Cfg.PLATFORM_RAIL_H
					- StructureKit.RAIL_SECTION * 0.5,
				- run * 0.5)))
	_handrails.add_child(_mm("Posts", StructureKit.rail_post_mesh(), posts))
	_handrails.add_child(_mm("Rails", StructureKit.rail_mesh(), rails))
	if placement_preview:
		return


	for side: float in [-1.0, 1.0]:
		var wall:= CollisionShape3D.new()
		wall.name = "HandrailCollision%s" % ("L" if side < 0.0 else "R")
		var box:= BoxShape3D.new()
		box.size = Vector3(Railing.COLLIDER_THICK, Cfg.PLATFORM_RAIL_H, slope)
		wall.shape = box
		wall.transform = Transform3D(tilt, Vector3(
			half * side,
			- rise * 0.5 + Cfg.PLATFORM_RAIL_H * 0.5,
			- run * 0.5))
		add_child(wall)


func _mm(mm_name: String, mesh: Mesh,
		xforms: Array [Transform3D]) -> MultiMeshInstance3D:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms [i])
	var mmi:= MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	if placement_preview:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


func _build_collider() -> void:
	if _shape == null:
		_shape = BoxShape3D.new()
		_collision = CollisionShape3D.new()
		_collision.name = "RampCollision"
		_collision.shape = _shape
		add_child(_collision)
	var run:= run_for(rise, pitch)
	var slope:= sqrt(run * run + rise * rise)
	const RAMP_THICK:= 0.3
	_shape.size = Vector3(Cfg.STAIR_WIDTH, RAMP_THICK, slope)
	var tilt:= Basis(Vector3.RIGHT, - atan2(rise, run))
	var surface:= Vector3(0.0, - rise * 0.5, - run * 0.5)
	_collision.transform = Transform3D(tilt,
		surface + tilt * Vector3(0.0, - RAMP_THICK * 0.5, 0.0))


func set_preview_valid(valid: bool) -> void:
	if not placement_preview:
		return
	_preview_valid = valid
	var material:= ConveyorKit.ghost_material(valid)
	if _treads != null:
		_treads.material_override = material
	if _stringers != null:
		for child in _stringers.get_children():
			var mi:= child as MeshInstance3D
			if mi != null:
				mi.material_override = material
	if _handrails == null:
		return
	for child in _handrails.get_children():
		var mmi:= child as MultiMeshInstance3D
		if mmi != null:
			mmi.material_override = material


func to_dict() -> Dictionary:
	return {
		"type": "stair",
		"position": position,
		"yaw": rotation.y,
		"rise": rise,
		"pitch": pitch,
		"paid": build_cost(),
	}
